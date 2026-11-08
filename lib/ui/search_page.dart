import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final c = TextEditingController();
  List<Anime> res = [];
  bool busy = false;
  String? note;

  Future<void> go(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    setState(() {
      busy = true;
      note = null;
      res = app.db.animes('title LIKE ?', ['%$q%']);
    });
    try {
      final r = await app.api.query(search: q, sort: 'SEARCH_MATCH', per: 30);
      for (final a in r) {
        app.db.upsertAnime(a);
      }
      app.db.bump();
      if (mounted) setState(() => res = r);
    } catch (_) {
      if (mounted) setState(() => note = 'Sem internet: mostrando só resultados salvos no aparelho.');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: c,
            textInputAction: TextInputAction.search,
            onSubmitted: go,
            decoration: InputDecoration(
              hintText: 'Buscar anime…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => go(c.text)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (note != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(note!, style: const TextStyle(color: Colors.amber))),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170, childAspectRatio: .5, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: res.length,
            itemBuilder: (_, i) => Poster(res[i]),
          ),
        ),
      ]);
}
