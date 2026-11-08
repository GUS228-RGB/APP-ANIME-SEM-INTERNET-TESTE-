import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'models.dart';

const _schema = '''
CREATE TABLE IF NOT EXISTS anime(
  id INTEGER PRIMARY KEY, title TEXT, synopsis TEXT, cover TEXT, banner TEXT,
  cover_path TEXT DEFAULT '', banner_path TEXT DEFAULT '', status TEXT, genres TEXT,
  episodes INT DEFAULT 0, year INT DEFAULT 0, score REAL DEFAULT 0,
  in_list INT DEFAULT 0, favorite INT DEFAULT 0);
CREATE TABLE IF NOT EXISTS episode(
  id INTEGER PRIMARY KEY AUTOINCREMENT, anime_id INT, season INT DEFAULT 1, number INT,
  title TEXT DEFAULT '', lang TEXT DEFAULT 'unknown', quality TEXT DEFAULT '',
  source_url TEXT DEFAULT '', file_path TEXT DEFAULT '', size INT DEFAULT 0,
  downloaded INT DEFAULT 0, status TEXT DEFAULT 'none', position_ms INT DEFAULT 0,
  duration_ms INT DEFAULT 0, watched INT DEFAULT 0, last_watched INT DEFAULT 0);
CREATE UNIQUE INDEX IF NOT EXISTS ep_unique ON episode(anime_id, season, number, lang);
CREATE TABLE IF NOT EXISTS catalog_row(row_key TEXT, anime_id INT, pos INT);
CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v TEXT);
''';

class Db extends ChangeNotifier {
  late final Database _d;
  late final String root;

  Future<void> init() async {
    root = (await getApplicationSupportDirectory()).path;
    _d = sqlite3.open(p.join(root, 'animeflix.db'));
    _d.execute('PRAGMA journal_mode=WAL');
    _d.execute(_schema);
  }

  void bump() => notifyListeners();

  List<Map<String, Object?>> q(String sql, [List<Object?> a = const []]) =>
      _d.select(sql, a).map((r) => Map<String, Object?>.from(r)).toList();

  void run(String sql, [List<Object?> a = const [], bool notify = true]) {
    _d.execute(sql, a);
    if (notify) notifyListeners();
  }

  // ---------- kv ----------
  String? kv(String k) {
    final r = _d.select('SELECT v FROM kv WHERE k=?', [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  void setKv(String k, String v) => _d.execute(
      'INSERT INTO kv VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v', [k, v]);

  // ---------- anime ----------
  void upsertAnime(Anime a) => _d.execute('''
    INSERT INTO anime(id,title,synopsis,cover,banner,status,genres,episodes,year,score)
    VALUES(?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(id) DO UPDATE SET title=excluded.title, synopsis=excluded.synopsis,
      cover=excluded.cover, banner=excluded.banner, status=excluded.status,
      genres=excluded.genres, episodes=excluded.episodes, year=excluded.year, score=excluded.score''',
      [a.id, a.title, a.synopsis, a.cover, a.banner, a.status, a.genres, a.episodes, a.year, a.score]);

  Anime? anime(int id) {
    final r = q('SELECT * FROM anime WHERE id=?', [id]);
    return r.isEmpty ? null : Anime.fromRow(r.first);
  }

  List<Anime> animes(String where, [List<Object?> a = const []]) =>
      q('SELECT * FROM anime WHERE $where', a).map(Anime.fromRow).toList();

  void setRow(String key, List<int> ids) {
    _d.execute('DELETE FROM catalog_row WHERE row_key=?', [key]);
    for (var i = 0; i < ids.length; i++) {
      _d.execute('INSERT INTO catalog_row VALUES(?,?,?)', [key, ids[i], i]);
    }
  }

  List<Anime> row(String key) => q(
          'SELECT a.* FROM catalog_row r JOIN anime a ON a.id=r.anime_id WHERE r.row_key=? ORDER BY r.pos',
          [key])
      .map(Anime.fromRow)
      .toList();

  void setFlag(int id, String col, bool v) {
    assert(col == 'in_list' || col == 'favorite');
    run('UPDATE anime SET $col=? WHERE id=?', [v ? 1 : 0, id]);
  }

  void setImg(int id, String col, String path) {
    assert(col == 'cover_path' || col == 'banner_path');
    _d.execute('UPDATE anime SET $col=? WHERE id=?', [path, id]);
  }

  List<Anime> animesWithLang(List<String> langs) {
    final ph = List.filled(langs.length, '?').join(',');
    return q('SELECT DISTINCT a.* FROM anime a JOIN episode e ON e.anime_id=a.id WHERE e.lang IN ($ph)', langs)
        .map(Anime.fromRow)
        .toList();
  }

  List<Anime> downloadedAnimes() => q(
          "SELECT DISTINCT a.* FROM anime a JOIN episode e ON e.anime_id=a.id WHERE e.status='done' ORDER BY a.title")
      .map(Anime.fromRow)
      .toList();

  // ---------- episódios ----------
  List<Episode> episodes(int animeId) => q(
          'SELECT * FROM episode WHERE anime_id=? ORDER BY season,number,lang', [animeId])
      .map(Episode.fromRow)
      .toList();

  Episode? episode(int id) {
    final r = q('SELECT * FROM episode WHERE id=?', [id]);
    return r.isEmpty ? null : Episode.fromRow(r.first);
  }

  /// Retorna o id, ou -1 se já existia (evita duplicados).
  int addEpisode({
    required int animeId,
    required int season,
    required int number,
    String title = '',
    String lang = 'unknown',
    String quality = '',
    String url = '',
    String file = '',
    int size = 0,
    String status = 'none',
  }) {
    if (url.isNotEmpty &&
        q('SELECT 1 FROM episode WHERE anime_id=? AND source_url=?', [animeId, url]).isNotEmpty) {
      return -1;
    }
    _d.execute(
        'INSERT OR IGNORE INTO episode(anime_id,season,number,title,lang,quality,source_url,file_path,size,status) VALUES(?,?,?,?,?,?,?,?,?,?)',
        [animeId, season, number, title, lang, quality, url, file, size, status]);
    if (_d.updatedRows == 0) return -1;
    final id = _d.lastInsertRowId;
    notifyListeners();
    return id;
  }

  void epSet(int id, Map<String, Object?> m, {bool notify = true}) {
    final cols = m.keys.map((k) => '$k=?').join(',');
    _d.execute('UPDATE episode SET $cols WHERE id=?', [...m.values, id]);
    if (notify) notifyListeners();
  }

  void deleteEpisodeRow(int id) {
    final e = episode(id);
    if (e != null && e.filePath.isNotEmpty) {
      try {
        File(e.filePath).deleteSync();
      } catch (_) {}
    }
    run('DELETE FROM episode WHERE id=?', [id]);
  }

  int usedBytes() {
    final r = _d.select("SELECT COALESCE(SUM(CASE WHEN status='done' THEN size ELSE downloaded END),0) AS s FROM episode");
    return (r.first['s'] as num).toInt();
  }

  List<Episode> continueWatching() {
    final all = q(
            "SELECT * FROM episode WHERE status='done' AND position_ms>5000 AND watched=0 ORDER BY last_watched DESC LIMIT 60")
        .map(Episode.fromRow);
    final seen = <int>{};
    return all.where((e) => seen.add(e.animeId)).take(30).toList();
  }

  List<Episode> history() => q('SELECT * FROM episode WHERE last_watched>0 ORDER BY last_watched DESC LIMIT 100')
      .map(Episode.fromRow)
      .toList();

  /// Próximo episódio baixado (mesma temporada ou primeiro da próxima). Prefere o mesmo idioma.
  Episode? nextOf(Episode e) {
    final all = q("SELECT * FROM episode WHERE anime_id=? AND status='done' ORDER BY season,number", [e.animeId])
        .map(Episode.fromRow)
        .toList();
    final c = all.where((x) => x.season > e.season || (x.season == e.season && x.number > e.number)).toList();
    if (c.isEmpty) return null;
    final first = c.first;
    final same = c.where((x) => x.season == first.season && x.number == first.number);
    return same.firstWhere((x) => x.lang == e.lang, orElse: () => first);
  }
}
