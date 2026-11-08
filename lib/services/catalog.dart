import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/db.dart';
import '../core/models.dart';
import 'anilist.dart';

/// Atualiza o catálogo automaticamente e guarda tudo (metadados + imagens) localmente.
class Catalog extends ChangeNotifier {
  Catalog(this.db, this.api);
  final Db db;
  final AniList api;
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
  bool loading = false;
  String? error;

  static const keys = ['popular', 'new', 'trending', 'airing', 'finished', 'recs'];

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    final last = int.tryParse(db.kv('catalog_ts') ?? '') ?? 0;
    final fresh = DateTime.now().millisecondsSinceEpoch - last < 6 * 3600 * 1000;
    if (!force && fresh && db.row('popular').isNotEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final count = <String, int>{};
      for (final a in db.animes('in_list=1 OR favorite=1')) {
        for (final g in a.genreList) {
          count[g] = (count[g] ?? 0) + 1;
        }
      }
      final top = (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(2)
          .map((e) => e.key)
          .toList();
      Future<List<Anime>> safe(Future<List<Anime>> f) => f.catchError((_) => <Anime>[]);
      final jobs = <String, Future<List<Anime>>>{
        'popular': safe(api.query(sort: 'POPULARITY_DESC')),
        'new': safe(api.query(sort: 'START_DATE_DESC', status: 'RELEASING')),
        'trending': safe(api.query(sort: 'TRENDING_DESC')),
        'airing': safe(api.query(sort: 'POPULARITY_DESC', status: 'RELEASING')),
        'finished': safe(api.query(sort: 'SCORE_DESC', status: 'FINISHED')),
        'recs': safe(api.query(sort: 'SCORE_DESC', genres: top.isEmpty ? null : top)),
      };
      final names = jobs.keys.toList();
      final res = await Future.wait(jobs.values);
      var ok = 0;
      for (var i = 0; i < names.length; i++) {
        if (res[i].isEmpty) continue;
        ok++;
        for (final a in res[i]) {
          db.upsertAnime(a);
        }
        db.setRow(names[i], res[i].map((a) => a.id).toList());
      }
      if (ok == 0) {
        error = 'Sem conexão. Mostrando o catálogo salvo.';
      } else {
        db.setKv('catalog_ts', '${DateTime.now().millisecondsSinceEpoch}');
      }
      db.bump();
    } catch (_) {
      error = 'Falha ao atualizar o catálogo. Mostrando o catálogo salvo.';
    }
    loading = false;
    notifyListeners();
    if (error == null) unawaited(cacheImages());
  }

  Future<void> _grab(Anime a, bool banner) async {
    final url = banner ? a.banner : a.cover;
    final cur = banner ? a.bannerPath : a.coverPath;
    if (url.isEmpty || (cur.isNotEmpty && File(cur).existsSync())) return;
    try {
      final dir = Directory(p.join(db.root, 'img'))..createSync(recursive: true);
      final f = p.join(dir.path, '${banner ? 'b' : 'c'}${a.id}.jpg');
      await _dio.download(url, f);
      db.setImg(a.id, banner ? 'banner_path' : 'cover_path', f);
    } catch (_) {}
  }

  /// Baixa capas (e banners do destaque) para uso offline.
  Future<void> cacheImages() async {
    final seen = <int>{};
    final all = [for (final k in keys) ...db.row(k)].where((a) => seen.add(a.id)).toList();
    for (var i = 0; i < all.length; i += 4) {
      await Future.wait(all.skip(i).take(4).map((a) => _grab(a, false)));
    }
    await Future.wait(db.row('popular').take(6).map((a) => _grab(a, true)));
    db.bump();
  }

  Future<void> cacheOne(Anime a) async {
    final fresh = db.anime(a.id) ?? a;
    await _grab(fresh, false);
    await _grab(fresh, true);
    db.bump();
  }
}
