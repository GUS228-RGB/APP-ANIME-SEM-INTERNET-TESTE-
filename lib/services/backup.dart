import 'dart:convert';
import '../core/app.dart';
import '../core/models.dart';

/// "Sincronização" entre dispositivos por arquivo (sem servidor): exporta/importa lista, favoritos e progresso.
class Backup {
  static String dump() {
    final db = app.db;
    return jsonEncode({
      'v': 1,
      'anime': db.q('SELECT * FROM anime WHERE in_list=1 OR favorite=1 OR id IN (SELECT anime_id FROM episode)'),
      'episodes': db.q(
          'SELECT anime_id,season,number,lang,position_ms,watched,last_watched FROM episode WHERE last_watched>0 OR position_ms>0 OR watched=1'),
    });
  }

  static String restore(String json) {
    final db = app.db;
    final m = jsonDecode(json) as Map;
    var a = 0, e = 0;
    for (final r in (m['anime'] as List)) {
      final row = Map<String, Object?>.from(r as Map);
      final an = Anime.fromRow(row);
      db.upsertAnime(an);
      db.run('UPDATE anime SET in_list=MAX(in_list,?), favorite=MAX(favorite,?) WHERE id=?',
          [an.inList ? 1 : 0, an.favorite ? 1 : 0, an.id], false);
      a++;
    }
    for (final r in (m['episodes'] as List)) {
      final x = r as Map;
      db.run(
          'UPDATE episode SET position_ms=?, watched=MAX(watched,?), last_watched=? WHERE anime_id=? AND season=? AND number=? AND lang=? AND last_watched<?',
          [x['position_ms'], x['watched'], x['last_watched'], x['anime_id'], x['season'], x['number'], x['lang'], x['last_watched']],
          false);
      e++;
    }
    db.bump();
    return '$a animes e $e registros de progresso mesclados.';
  }
}
