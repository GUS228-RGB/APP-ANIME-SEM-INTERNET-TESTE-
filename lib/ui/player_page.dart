import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/app.dart';
import '../core/models.dart';

class _Ctl extends ChangeNotifier {
  String title = '';
  int? countdown;
  String? nextLabel;
  String? msg;
  VoidCallback? onNow;
  VoidCallback? onCancel;
  void update(void Function() f) {
    f();
    notifyListeners();
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.episodeId});
  final int episodeId;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final player = Player();
  late final VideoController vc = VideoController(player);
  final ctl = _Ctl();
  final subs = <StreamSubscription>[];
  Episode? ep;
  Timer? _save, _cd;
  bool _ending = false, _tracksDone = false;

  @override
  void initState() {
    super.initState();
    subs.add(player.stream.completed.listen((c) {
      if (c) _onEnd();
    }));
    subs.add(player.stream.tracks.listen(_onTracks));
    _save = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
    _load(widget.episodeId);
  }

  Future<void> _load(int id) async {
    _cd?.cancel();
    final e = app.db.episode(id);
    if (e == null || !File(e.filePath).existsSync()) {
      ctl.update(() {
        ctl.countdown = null;
        ctl.nextLabel = null;
        ctl.msg = 'Arquivo não encontrado. Baixe o episódio novamente.';
      });
      return;
    }
    ep = e;
    _ending = false;
    _tracksDone = false;
    final a = app.db.anime(e.animeId);
    ctl.update(() {
      ctl.title = '${a?.title ?? ''} · ${e.label}';
      ctl.countdown = null;
      ctl.nextLabel = null;
      ctl.msg = null;
    });
    await player.open(Media(e.filePath), play: true);
    if (e.positionMs > 5000 && !e.watched) {
      final d = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5), onTimeout: () => Duration.zero);
      if (d > Duration.zero) await player.seek(Duration(milliseconds: e.positionMs));
    }
  }

  void _persist({bool done = false}) {
    final e = ep;
    if (e == null) return;
    final pos = player.state.position.inMilliseconds;
    final dur = player.state.duration.inMilliseconds;
    if (dur <= 0) return;
    final watched = done || pos > dur * 0.92 || e.watched;
    app.db.epSet(
      e.id,
      {
        'position_ms': (done || pos > dur * 0.92) ? 0 : pos,
        'duration_ms': dur,
        'watched': watched ? 1 : 0,
        'last_watched': DateTime.now().millisecondsSinceEpoch,
      },
      notify: false,
    );
  }

  void _onTracks(Tracks t) {
    if (_tracksDone) return;
    final audio = t.audio.where((x) => x.id != 'auto' && x.id != 'no').toList();
    if (audio.isEmpty) return;
    _tracksDone = true;
    bool pt(String? l) => l != null && RegExp(r'^(pt|por)', caseSensitive: false).hasMatch(l);
    final ptAudio = audio.where((x) => pt(x.language)).toList();
    final ptSubs = t.subtitle.where((x) => x.id != 'auto' && x.id != 'no' && pt(x.language)).toList();
    final pref = app.settings.langFilter;
    if (pref != 'sub' && ptAudio.isNotEmpty) {
      player.setAudioTrack(ptAudio.first);
    } else if (ptSubs.isNotEmpty && (pref == 'sub' || ptAudio.isEmpty)) {
      player.setSubtitleTrack(ptSubs.first);
    }
    final e = ep;
    if (e != null && e.lang == 'unknown') {
      final nl = ptAudio.isNotEmpty ? (audio.length > ptAudio.length ? 'multi' : 'dub') : (ptSubs.isNotEmpty ? 'sub' : null);
      if (nl != null) {
        try {
          app.db.epSet(e.id, {'lang': nl}, notify: false);
        } catch (_) {}
      }
    }
  }

  void _onEnd() {
    if (_ending || ep == null) return;
    _ending = true;
    _persist(done: true);
    app.db.bump();
    final next = app.db.nextOf(ep!);
    if (next == null) {
      ctl.update(() => ctl.msg =
          'Fim dos episódios baixados. Baixe o próximo episódio (ou a próxima temporada) para continuar assistindo.');
      return;
    }
    ctl.onNow = () => _go(next.id);
    ctl.onCancel = _cancelNext;
    ctl.nextLabel = next.label;
    if (!app.settings.autoplay) {
      ctl.update(() => ctl.msg = 'Episódio concluído.');
      return;
    }
    final secs = app.settings.countdown;
    if (secs <= 0) {
      _go(next.id);
      return;
    }
    ctl.update(() => ctl.countdown = secs);
    _cd = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = (ctl.countdown ?? 1) - 1;
      if (left <= 0) {
        t.cancel();
        _go(next.id);
      } else {
        ctl.update(() => ctl.countdown = left);
      }
    });
  }

  void _go(int id) {
    _cd?.cancel();
    _load(id);
  }

  void _cancelNext() {
    _cd?.cancel();
    ctl.update(() {
      ctl.countdown = null;
      ctl.msg = 'Reprodução automática cancelada.';
    });
  }

  @override
  void dispose() {
    _save?.cancel();
    _cd?.cancel();
    _persist();
    app.db.bump();
    for (final s in subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Video(
          controller: vc,
          controls: (state) => _Controls(state: state, player: player, ctl: ctl),
        ),
      );
}

String _fmt(Duration d) {
  String t(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return '${h > 0 ? '$h:' : ''}${t(d.inMinutes % 60)}:${t(d.inSeconds % 60)}';
}

String _tn(String id, String? title, String? lang) {
  if (id == 'auto') return 'Automático';
  if (id == 'no') return 'Desativado';
  final s = [title, lang].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
  return s.isEmpty ? 'Faixa $id' : s;
}

class _Controls extends StatefulWidget {
  const _Controls({required this.state, required this.player, required this.ctl});
  final VideoState state;
  final Player player;
  final _Ctl ctl;
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool show = true;
  Timer? t;
  Player get p => widget.player;

  @override
  void initState() {
    super.initState();
    poke();
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void poke() {
    if (mounted) setState(() => show = true);
    t?.cancel();
    t = Timer(const Duration(seconds: 3), () {
      if (mounted && p.state.playing) setState(() => show = false);
    });
  }

  void seekBy(int s) {
    final n = p.state.position + Duration(seconds: s);
    p.seek(n < Duration.zero ? Duration.zero : n);
    poke();
  }

  Future<void> _back() async {
    if (widget.state.isFullscreen()) {
      await widget.state.exitFullscreen();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _loadSub() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'ass', 'vtt', 'ssa']);
    final path = r?.files.single.path;
    if (path != null) await p.setSubtitleTrack(SubtitleTrack.uri(path));
  }

  Widget _top() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
        ),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.ctl,
              builder: (_, __) => Text(widget.ctl.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          StreamBuilder<Tracks>(
            stream: p.stream.tracks,
            initialData: p.state.tracks,
            builder: (_, s) {
              final tr = s.data ?? p.state.tracks;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                PopupMenuButton<AudioTrack>(
                  icon: const Icon(Icons.audiotrack),
                  tooltip: 'Áudio',
                  onSelected: p.setAudioTrack,
                  itemBuilder: (_) => [
                    for (final a in tr.audio.where((a) => a.id != 'no'))
                      PopupMenuItem(value: a, child: Text(_tn(a.id, a.title, a.language))),
                  ],
                ),
                PopupMenuButton<Object>(
                  icon: const Icon(Icons.subtitles),
                  tooltip: 'Legendas',
                  onSelected: (v) => v == 'file' ? _loadSub() : p.setSubtitleTrack(v as SubtitleTrack),
                  itemBuilder: (_) => [
                    for (final a in tr.subtitle) PopupMenuItem<Object>(value: a, child: Text(_tn(a.id, a.title, a.language))),
                    const PopupMenuItem<Object>(value: 'file', child: Text('Carregar arquivo de legenda…')),
                  ],
                ),
              ]);
            },
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.speed),
            tooltip: 'Velocidade',
            onSelected: p.setRate,
            itemBuilder: (_) => [for (final v in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]) PopupMenuItem(value: v, child: Text('${v}x'))],
          ),
          ListenableBuilder(
            listenable: app.settings,
            builder: (_, __) => Row(children: [
              const Text('Auto', style: TextStyle(fontSize: 12)),
              Switch(value: app.settings.autoplay, onChanged: (v) => app.settings.set('autoplay', v ? '1' : '0')),
            ]),
          ),
        ]),
      );

  Widget _center() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(iconSize: 40, icon: const Icon(Icons.replay_10), onPressed: () => seekBy(-10)),
        const SizedBox(width: 16),
        StreamBuilder<bool>(
          stream: p.stream.playing,
          initialData: p.state.playing,
          builder: (_, s) => IconButton(
            iconSize: 60,
            icon: Icon(s.data! ? Icons.pause_circle_filled : Icons.play_circle_filled),
            onPressed: () {
              p.playOrPause();
              poke();
            },
          ),
        ),
        const SizedBox(width: 16),
        IconButton(iconSize: 40, icon: const Icon(Icons.forward_10), onPressed: () => seekBy(10)),
      ]);

  Widget _bottom() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
        ),
        child: Row(children: [
          StreamBuilder<Duration>(
            stream: p.stream.position,
            initialData: p.state.position,
            builder: (_, s) => Text(_fmt(s.data ?? Duration.zero), style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: p.stream.position,
              initialData: p.state.position,
              builder: (_, s) {
                final max = math.max(1.0, p.state.duration.inMilliseconds.toDouble());
                final v = math.min(max, math.max(0.0, (s.data ?? Duration.zero).inMilliseconds.toDouble()));
                return Slider(value: v, max: max, onChanged: (x) => p.seek(Duration(milliseconds: x.toInt())));
              },
            ),
          ),
          StreamBuilder<Duration>(
            stream: p.stream.duration,
            initialData: p.state.duration,
            builder: (_, s) => Text(_fmt(s.data ?? Duration.zero), style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.volume_up, size: 20),
          SizedBox(
            width: 100,
            child: StreamBuilder<double>(
              stream: p.stream.volume,
              initialData: p.state.volume,
              builder: (_, s) => Slider(value: math.min(100.0, math.max(0.0, s.data ?? 100.0)), max: 100, onChanged: p.setVolume),
            ),
          ),
          IconButton(
            icon: Icon(widget.state.isFullscreen() ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () async {
              await widget.state.toggleFullscreen();
              poke();
            },
          ),
        ]),
      );

  Widget _overlay() => ListenableBuilder(
        listenable: widget.ctl,
        builder: (_, __) {
          final c = widget.ctl;
          if (c.msg != null) {
            return Center(
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(c.msg!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, children: [
                        if (c.nextLabel != null && c.onNow != null)
                          FilledButton(onPressed: c.onNow, child: Text('Assistir ${c.nextLabel}')),
                        OutlinedButton(onPressed: _back, child: const Text('Voltar')),
                      ]),
                    ]),
                  ),
                ),
              ),
            );
          }
          if (c.countdown != null) {
            return Positioned(
              right: 24,
              bottom: 90,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Próximo: ${c.nextLabel} em ${c.countdown}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: c.onCancel, child: const Text('Cancelar')),
                      FilledButton(onPressed: c.onNow, child: const Text('Assistir agora')),
                    ]),
                  ]),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () => p.playOrPause(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => seekBy(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => seekBy(10),
          const SingleActivator(LogicalKeyboardKey.keyF): () => widget.state.toggleFullscreen(),
          const SingleActivator(LogicalKeyboardKey.escape): () => widget.state.exitFullscreen(),
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            onHover: (_) => poke(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => show ? setState(() => show = false) : poke(),
              onDoubleTap: () => widget.state.toggleFullscreen(),
              child: Stack(children: [
                if (show) ...[
                  Positioned(top: 0, left: 0, right: 0, child: _top()),
                  Center(child: _center()),
                  Positioned(bottom: 0, left: 0, right: 0, child: _bottom()),
                ],
                _overlay(),
              ]),
            ),
          ),
        ),
      );
}
