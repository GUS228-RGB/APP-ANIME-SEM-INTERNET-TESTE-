import 'package:dio/dio.dart';
import '../core/models.dart';

/// Catálogo: API pública e gratuita do AniList (GraphQL, sem chave).
class AniList {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const _fields =
      'id title{romaji english} description coverImage{large} bannerImage episodes status seasonYear averageScore genres';

  Future<List<Anime>> query({
    String sort = 'POPULARITY_DESC',
    String? status,
    String? search,
    List<String>? genres,
    int per = 24,
  }) async {
    final q = 'query(\$per:Int,\$sort:[MediaSort],\$status:MediaStatus,\$search:String,\$genres:[String]){'
        'Page(page:1,perPage:\$per){media(type:ANIME,isAdult:false,sort:\$sort,status:\$status,search:\$search,genre_in:\$genres){$_fields}}}';
    final res = await _dio.post('https://graphql.anilist.co', data: {
      'query': q,
      'variables': {
        'per': per,
        'sort': [sort],
        if (status != null) 'status': status,
        if (search != null) 'search': search,
        if (genres != null) 'genres': genres,
      },
    });
    final list = res.data['data']['Page']['media'] as List;
    return list.map((m) => _map(m as Map)).toList();
  }

  Anime _map(Map m) {
    final t = (m['title'] ?? {}) as Map;
    final c = (m['coverImage'] ?? {}) as Map;
    final desc = ((m['description'] ?? '') as String).replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return Anime(
      id: m['id'] as int,
      title: (t['english'] ?? t['romaji'] ?? '') as String,
      synopsis: desc,
      cover: (c['large'] ?? '') as String,
      banner: (m['bannerImage'] ?? '') as String,
      status: (m['status'] ?? '') as String,
      genres: ((m['genres'] ?? []) as List).join(','),
      episodes: (m['episodes'] ?? 0) as int,
      year: (m['seasonYear'] ?? 0) as int,
      score: ((m['averageScore'] ?? 0) as num).toDouble() / 10,
    );
  }
}
