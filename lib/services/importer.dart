import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/app.dart';
import '../core/models.dart';

/// Importa arquivos de vídeo que o próprio usuário possui (ex.: backups das suas mídias).
class Importer {
  static ({int season, int number}) parse(String name, int fallback, int defSeason) {
    final se = RegExp(r'[sS](\d{1,2})[ ._-]*[eE](\d{1,4})').firstMatch(name);
    if (se != null) return (season: int.parse(se[1]!), number: int.parse(se[2]!));
    final ep = RegExp(r'[eE][pP]?[ ._-]?(\d{1,4})(?!\d)').firstMatch(name);
    if (ep != null) return (season: defSeason, number: int.parse(ep[1]!));
    const skip = {480, 720, 1080, 2160, 264, 265, 1920, 1280};
    final nums = RegExp(r'(?<![\dA-Za-z])(\d{1,3})(?![\dA-Za-z])')
        .allMatches(name)
        .map((m) => int.parse(m[1]!))
        .where((n) => !skip.contains(n) && n > 0)
        .toList();
    return (season: defSeason, number: nums.isNotEmpty ? nums.last : fallback);
  }

  static Future<String> importFiles(Anime a, List<String> paths, String lang, int season) async {
    var ok = 0, dup = 0, fail = 0, i = 0;
    for (final src in paths) {
      i++;
      final r = parse(p.basenameWithoutExtension(src), i, season);
      final dir = Directory(p.join(app.db.root, 'videos', '${a.id}', 'T${r.season}'))..createSync(recursive: true);
      final dest = p.join(dir.path, 'E${r.number.toString().padLeft(3, '0')}_$lang${p.extension(src)}');
      final id = app.db.addEpisode(
        animeId: a.id,
        season: r.season,
        number: r.number,
        lang: lang,
        file: dest,
        status: 'done',
      );
      if (id < 0) {
        dup++;
        continue;
      }
      try {
        await File(src).copy(dest);
        final n = File(dest).lengthSync();
        app.db.epSet(id, {'size': n, 'downloaded': n});
        ok++;
      } catch (_) {
        app.db.deleteEpisodeRow(id);
        fail++;
      }
    }
    app.catalog.cacheOne(a);
    return '$ok importado(s)${dup > 0 ? ', $dup já existia(m)' : ''}${fail > 0 ? ', $fail falharam' : ''}.';
  }
}
