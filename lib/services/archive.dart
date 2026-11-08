import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/models.dart';

class SrcItem {
  final String id, title, lang, license;
  SrcItem(this.id, this.title, this.lang, this.license);
}

class SrcFile {
  final String name, format, url;
  final int size;
  SrcFile(this.name, this.format, this.url, this.size);
  String get quality => '${format.toUpperCase()} · ${fmtBytes(size)}';
}

/// Fonte legal: Internet Archive (somente itens Creative Commons / domínio público / animação livre).
class ArchiveSource {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  dynamic _json(dynamic d) => d is String ? jsonDecode(d) : d;

  Future<List<SrcItem>> search(String text) async {
    final t = text.replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ').trim();
    if (t.isEmpty) return [];
    final q = '(title:($t) OR subject:($t)) AND mediatype:(movies) AND '
        '(licenseurl:(*creativecommons*) OR collection:(animationandcartoons))';
    final url = 'https://archive.org/advancedsearch.php?q=${Uri.encodeQueryComponent(q)}'
        '&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=language&fl%5B%5D=licenseurl&rows=25&output=json';
    final r = await _dio.get(url);
    final docs = (_json(r.data)['response']['docs'] as List);
    return docs
        .map((d) => SrcItem(
              '${d['identifier']}',
              '${d['title'] ?? d['identifier']}',
              '${d['language'] is List ? (d['language'] as List).join(',') : d['language'] ?? ''}',
              '${d['licenseurl'] ?? ''}',
            ))
        .toList();
  }

  /// Retorna idioma sugerido ('dub' só se os metadados disserem português) e os arquivos de vídeo.
  Future<({String lang, List<SrcFile> files})> files(String id) async {
    final r = await _dio.get('https://archive.org/metadata/$id');
    final data = _json(r.data) as Map;
    final langMeta = '${(data['metadata'] ?? {})['language'] ?? ''}'.toLowerCase();
    final isPt = langMeta.contains('por') || langMeta.contains('portugu') || langMeta == 'pt';
    const ok = {'mp4', 'mkv', 'webm', 'ogv', 'avi', 'm4v'};
    final out = <SrcFile>[];
    for (final f in (data['files'] as List? ?? [])) {
      final name = '${f['name']}';
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!ok.contains(ext)) continue;
      final url = 'https://archive.org/download/$id/${name.split('/').map(Uri.encodeComponent).join('/')}';
      out.add(SrcFile(name, ext, url, int.tryParse('${f['size']}') ?? 0));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return (lang: isPt ? 'dub' : 'unknown', files: out);
  }
}
