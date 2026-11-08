import 'dart:io';
import 'package:flutter/material.dart';
import '../core/models.dart';
import 'detail_page.dart';

Widget _ph() => Container(color: const Color(0xFF1C1C24), child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white24)));

/// Mostra a imagem salva localmente (offline) ou, se não houver, da internet.
Widget img(String local, String url, {BoxFit fit = BoxFit.cover}) {
  if (local.isNotEmpty && File(local).existsSync()) return Image.file(File(local), fit: fit, errorBuilder: (_, __, ___) => _ph());
  if (url.isEmpty) return _ph();
  return Image.network(url, fit: fit, errorBuilder: (_, __, ___) => _ph());
}

void openAnime(BuildContext c, int id) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => DetailPage(animeId: id)));

class LangBadge extends StatelessWidget {
  const LangBadge(this.lang, {super.key});
  final String lang;
  @override
  Widget build(BuildContext context) {
    final c = switch (lang) {
      'dub' => const Color(0xFF1B9E4B),
      'sub' => const Color(0xFF2F6FDE),
      'multi' => const Color(0xFF8E44AD),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(.25), border: Border.all(color: c), borderRadius: BorderRadius.circular(4)),
      child: Text(langLabel(lang), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class Poster extends StatefulWidget {
  const Poster(this.a, {super.key, this.w, this.progress, this.onTap, this.subtitle});
  final Anime a;
  final double? w;
  final double? progress;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  State<Poster> createState() => _PosterState();
}

class _PosterState extends State<Poster> {
  bool hov = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final col = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            img(a.coverPath, a.cover),
            if (widget.progress != null)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(value: widget.progress, minHeight: 4, color: const Color(0xFFE50914), backgroundColor: Colors.black54),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      if (widget.subtitle != null) Text(widget.subtitle!, style: const TextStyle(fontSize: 11, color: Colors.white54)),
    ]);
    return MouseRegion(
      onEnter: (_) => setState(() => hov = true),
      onExit: (_) => setState(() => hov = false),
      child: AnimatedScale(
        scale: hov ? 1.05 : 1,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.onTap ?? () => openAnime(context, a.id),
          child: widget.w == null ? col : SizedBox(width: widget.w, child: col),
        ),
      ),
    );
  }
}

class HRow extends StatelessWidget {
  const HRow(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width >= 800 ? 150.0 : 112.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: w * 1.5 + 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(width: w, child: children[i]),
        ),
      ),
    ]);
  }
}
