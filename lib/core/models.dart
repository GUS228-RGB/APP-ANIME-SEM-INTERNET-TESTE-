class Anime {
  final int id, episodes, year;
  final String title, synopsis, cover, banner, status, genres, coverPath, bannerPath;
  final double score;
  final bool inList, favorite;
  const Anime({
    required this.id,
    required this.title,
    this.synopsis = '',
    this.cover = '',
    this.banner = '',
    this.status = '',
    this.genres = '',
    this.coverPath = '',
    this.bannerPath = '',
    this.episodes = 0,
    this.year = 0,
    this.score = 0,
    this.inList = false,
    this.favorite = false,
  });

  factory Anime.fromRow(Map<String, Object?> r) => Anime(
        id: r['id'] as int,
        title: (r['title'] ?? '') as String,
        synopsis: (r['synopsis'] ?? '') as String,
        cover: (r['cover'] ?? '') as String,
        banner: (r['banner'] ?? '') as String,
        status: (r['status'] ?? '') as String,
        genres: (r['genres'] ?? '') as String,
        coverPath: (r['cover_path'] ?? '') as String,
        bannerPath: (r['banner_path'] ?? '') as String,
        episodes: (r['episodes'] ?? 0) as int,
        year: (r['year'] ?? 0) as int,
        score: ((r['score'] ?? 0) as num).toDouble(),
        inList: (r['in_list'] ?? 0) == 1,
        favorite: (r['favorite'] ?? 0) == 1,
      );

  List<String> get genreList => genres.isEmpty ? [] : genres.split(',');
}

class Episode {
  final int id, animeId, season, number, size, downloaded, positionMs, durationMs, lastWatched;
  final String title, lang, quality, sourceUrl, filePath, status;
  final bool watched;
  const Episode({
    required this.id,
    required this.animeId,
    required this.season,
    required this.number,
    required this.title,
    required this.lang,
    required this.quality,
    required this.sourceUrl,
    required this.filePath,
    required this.status,
    required this.size,
    required this.downloaded,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatched,
    required this.watched,
  });

  factory Episode.fromRow(Map<String, Object?> r) => Episode(
        id: r['id'] as int,
        animeId: r['anime_id'] as int,
        season: (r['season'] ?? 1) as int,
        number: (r['number'] ?? 0) as int,
        title: (r['title'] ?? '') as String,
        lang: (r['lang'] ?? 'unknown') as String,
        quality: (r['quality'] ?? '') as String,
        sourceUrl: (r['source_url'] ?? '') as String,
        filePath: (r['file_path'] ?? '') as String,
        status: (r['status'] ?? 'none') as String,
        size: (r['size'] ?? 0) as int,
        downloaded: (r['downloaded'] ?? 0) as int,
        positionMs: (r['position_ms'] ?? 0) as int,
        durationMs: (r['duration_ms'] ?? 0) as int,
        lastWatched: (r['last_watched'] ?? 0) as int,
        watched: (r['watched'] ?? 0) == 1,
      );

  String get label => 'T$season · E${number.toString().padLeft(2, '0')}';
  bool get isDone => status == 'done' && filePath.isNotEmpty;
}

String langLabel(String l) => switch (l) {
      'dub' => 'DUBLADO PT-BR',
      'sub' => 'LEGENDADO',
      'multi' => 'DUB + LEG',
      _ => 'IDIOMA ?',
    };

/// filtro: dub | sub | both
bool langMatch(String filter, String lang) => switch (filter) {
      'dub' => lang == 'dub' || lang == 'multi',
      'sub' => lang != 'dub',
      _ => true,
    };

String statusPt(String s) => switch (s) {
      'RELEASING' => 'Em andamento',
      'FINISHED' => 'Finalizado',
      'NOT_YET_RELEASED' => 'Em breve',
      'CANCELLED' => 'Cancelado',
      'HIATUS' => 'Em hiato',
      _ => '',
    };

String fmtBytes(num b) {
  if (b <= 0) return '—';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  var v = b.toDouble();
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i < 2 ? 0 : 1)} ${u[i]}';
}
