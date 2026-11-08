import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import 'player_page.dart';
import 'widgets.dart';

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class EpisodeTile extends StatelessWidget {
  const EpisodeTile(this.e, {super.key, this.animeTitle});
  final Episode e;
  final String? animeTitle;

  void _play(BuildContext c) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => PlayerPage(episodeId: e.id)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.dl,
        builder: (context, _) {
          final live = app.dl.live[e.id];
          final got = live?.got ?? e.downloaded;
          final total = live?.total ?? e.size;
          final busy = e.status == 'downloading' || e.status == 'queued';
          final pct = (total > 0 && got > 0) ? got / total : null;
          final dl = app.dl;
          Widget trailing;
          if (e.isDone) {
            trailing = Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.play_circle_fill, size: 32), onPressed: () => _play(context)),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'del') {
                    dl.removeFile(e.id);
                  } else {
                    try {
                      app.db.epSet(e.id, {'lang': v});
                    } catch (_) {
                      snack(context, 'Já existe este episódio com esse idioma.');
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'dub', child: Text('Marcar como Dublado PT-BR')),
                  PopupMenuItem(value: 'sub', child: Text('Marcar como Legendado')),
                  PopupMenuItem(value: 'multi', child: Text('Marcar como Dub + Leg')),
                  PopupMenuItem(value: 'del', child: Text('Excluir arquivo')),
                ],
              ),
            ]);
          } else if (busy) {
            trailing = Row(mainAxisSize: MainAxisSize.min, children: [
              if (e.status == 'downloading') IconButton(icon: const Icon(Icons.pause), onPressed: () => dl.pause(e.id)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => dl.cancel(e.id)),
            ]);
          } else if (e.status == 'paused' || e.status == 'error') {
            trailing = Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Continuar',
                onPressed: () {
                  final m = dl.enqueue(e.id);
                  if (m != null) snack(context, m);
                },
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => dl.cancel(e.id)),
            ]);
          } else if (e.sourceUrl.isNotEmpty) {
            trailing = IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                final m = dl.enqueue(e.id);
                if (m != null) snack(context, m);
              },
            );
          } else {
            trailing = const SizedBox.shrink();
          }

          final speed = live != null && live.speed > 0 ? ' · ${fmtBytes(live.speed)}/s' : '';
          final status = switch (e.status) {
            'queued' => 'Na fila',
            'paused' => 'Pausado ${fmtBytes(got)} / ${fmtBytes(total)}',
            'error' => 'Erro: ${dl.errors[e.id] ?? 'falha'}',
            'downloading' => '${fmtBytes(got)} / ${fmtBytes(total)}$speed',
            'done' => fmtBytes(e.size),
            _ => e.size > 0 ? fmtBytes(e.size) : 'Não baixado',
          };

          return ListTile(
            onTap: e.isDone ? () => _play(context) : null,
            title: Text('${animeTitle != null ? '$animeTitle · ' : ''}${e.label}${e.title.isNotEmpty ? ' — ${e.title}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                LangBadge(e.lang),
                if (e.quality.isNotEmpty) Text(e.quality, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                Text(status, style: const TextStyle(fontSize: 12)),
              ]),
              if (busy || e.status == 'paused')
                Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: pct)),
              if (e.isDone && e.durationMs > 0 && e.positionMs > 0 && !e.watched)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(value: e.positionMs / e.durationMs, minHeight: 3, color: const Color(0xFFE50914)),
                ),
            ]),
            trailing: trailing,
          );
        },
      );
}
