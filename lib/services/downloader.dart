import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/db.dart';
import '../core/models.dart';
import '../core/settings.dart';

class DlInfo {
  final int got, total;
  final double speed; // bytes/s
  DlInfo(this.got, this.total, this.speed);
}

/// Fila de downloads com retomada (HTTP Range), pausa, cancelamento e limite de armazenamento.
class Downloader extends ChangeNotifier {
  Downloader(this.db, this.st);
  final Db db;
  final Settings st;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final Map<int, DlInfo> live = {};
  final Map<int, String> errors = {};
  final Map<int, CancelToken> _tokens = {};
  final Map<int, String> _stop = {};
  final List<int> _queue = [];
  static const _max = 2;

  /// Nada baixa sozinho ao abrir o app: o que estava em andamento fica pausado.
  void recover() => db.run(
      "UPDATE episode SET status='paused' WHERE status IN ('downloading','queued')", const [], false);

  String _pathOf(Episode e) {
    final dir = Directory(p.join(db.root, 'videos', '${e.animeId}', 'T${e.season}'))..createSync(recursive: true);
    var ext = p.extension(Uri.parse(e.sourceUrl).path);
    if (ext.isEmpty || ext.length > 5) ext = '.mp4';
    return p.join(dir.path, 'E${e.number.toString().padLeft(3, '0')}_${e.lang}$ext');
  }

  /// Retorna mensagem de erro (ou null).
  String? enqueue(int id) {
    final e = db.episode(id);
    if (e == null || e.isDone || e.sourceUrl.isEmpty) return null;
    if (_queue.contains(id) || _tokens.containsKey(id)) return null;
    final limit = st.limitGb;
    if (limit > 0 && db.usedBytes() + e.size > limit * 1e9) {
      return 'Limite de armazenamento atingido. Aumente em Configurações.';
    }
    errors.remove(id);
    db.epSet(id, {'status': 'queued'});
    _queue.add(id);
    _pump();
    return null;
  }

  String? enqueueAll(Iterable<int> ids) {
    String? err;
    for (final id in ids) {
      err ??= enqueue(id);
    }
    return err;
  }

  void _pump() {
    while (_tokens.length < _max && _queue.isNotEmpty) {
      _run(_queue.removeAt(0));
    }
  }

  void pause(int id) {
    if (_tokens.containsKey(id)) {
      _stop[id] = 'pause';
      _tokens[id]!.cancel();
    } else if (_queue.remove(id)) {
      db.epSet(id, {'status': 'paused'});
    }
  }

  void cancel(int id) {
    if (_tokens.containsKey(id)) {
      _stop[id] = 'cancel';
      _tokens[id]!.cancel();
      return;
    }
    _queue.remove(id);
    final e = db.episode(id);
    if (e == null) return;
    try {
      File('${_pathOf(e)}.part').deleteSync();
    } catch (_) {}
    db.epSet(id, {'status': 'none', 'downloaded': 0});
  }

  /// Apaga o arquivo baixado. Se houver fonte, mantém o item para baixar de novo.
  void removeFile(int id) {
    final e = db.episode(id);
    if (e == null) return;
    if (e.sourceUrl.isEmpty) {
      db.deleteEpisodeRow(id);
      return;
    }
    try {
      File(e.filePath).deleteSync();
    } catch (_) {}
    db.epSet(id, {'status': 'none', 'file_path': '', 'downloaded': 0});
  }

  Future<void> _run(int id) async {
    final e = db.episode(id)!;
    final token = CancelToken();
    _tokens[id] = token;
    final path = _pathOf(e);
    final part = '$path.part';
    var have = File(part).existsSync() ? File(part).lengthSync() : 0;
    db.epSet(id, {'status': 'downloading'});
    IOSink? sink;
    String? err;
    try {
      final res = await _dio.get<ResponseBody>(
        e.sourceUrl,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: have > 0 ? {'Range': 'bytes=$have-'} : null,
        ),
      );
      final resumed = res.statusCode == 206;
      if (!resumed) have = 0;
      final len = int.tryParse(res.headers.value('content-length') ?? '') ?? 0;
      final total = len > 0 ? len + have : e.size;
      sink = File(part).openWrite(mode: resumed ? FileMode.append : FileMode.write);
      var got = have;
      var tick = DateTime.now();
      var tickBytes = got;
      live[id] = DlInfo(got, total, 0);
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        got += chunk.length;
        final now = DateTime.now();
        final ms = now.difference(tick).inMilliseconds;
        if (ms >= 700) {
          live[id] = DlInfo(got, total, (got - tickBytes) * 1000 / ms);
          tick = now;
          tickBytes = got;
          notifyListeners();
        }
      }
      if (!token.isCancelled) {
        await sink.flush();
        await sink.close();
        sink = null;
        File(part).renameSync(path);
        db.epSet(id, {'status': 'done', 'file_path': path, 'size': got, 'downloaded': got});
      }
    } catch (ex) {
      if (!token.isCancelled) err = ex is DioException ? (ex.message ?? 'Falha de rede') : '$ex';
    }
    try {
      await sink?.close();
    } catch (_) {}
    final reason = _stop.remove(id);
    _tokens.remove(id);
    live.remove(id);
    final partLen = File(part).existsSync() ? File(part).lengthSync() : 0;
    final cur = db.episode(id);
    if (cur != null && cur.status != 'done') {
      if (reason == 'cancel') {
        try {
          File(part).deleteSync();
        } catch (_) {}
        db.epSet(id, {'status': 'none', 'downloaded': 0});
      } else if (reason == 'pause') {
        db.epSet(id, {'status': 'paused', 'downloaded': partLen});
      } else {
        errors[id] = err ?? 'Download interrompido';
        db.epSet(id, {'status': 'error', 'downloaded': partLen});
      }
    }
    notifyListeners();
    _pump();
  }
}
