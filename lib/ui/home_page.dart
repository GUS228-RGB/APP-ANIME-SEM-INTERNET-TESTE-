import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import 'player_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => app.catalog.refresh());
  }

  List<Widget> _posters(List<Anime> l) => [for (final a in l) Poster(a)];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.db, app.catalog, app.settings]),
        builder: (context, _) {
          final db = app.db;
          final pref = app.settings.langFilter;
          final cont = db.continueWatching();
          final hero = db
              .row('popular')
              .where((a) => a.banner.isNotEmpty || a.bannerPath.isNotEmpty)
              .take(6)
              .toList();
          final dub = db.animesWithLang(['dub', 'multi']);
          final sub = db.animesWithLang(['sub', 'multi']);
          final dubRow = ('Animes dublados (PT-BR)', dub);
          final subRow = ('Animes legendados', sub);
          final rows = <(String, List<Anime>)>[
            ...(pref == 'sub' ? [subRow, dubRow] : [dubRow, subRow]),
            ('Populares', db.row('popular')),
            ('Lançamentos', db.row('new')),
            ('Mais assistidos', db.row('trending')),
            ('Em andamento', db.row('airing')),
            ('Finalizados', db.row('finished')),
            ('Recomendações', db.row('recs')),
          ];
          return RefreshIndicator(
            onRefresh: () => app.catalog.refresh(force: true),
            child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              if (hero.isNotEmpty) HeroBanner(hero),
              if (app.catalog.loading) const LinearProgressIndicator(minHeight: 2),
              if (app.catalog.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.wifi_off, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(app.catalog.error!, style: const TextStyle(color: Colors.amber))),
                    TextButton(onPressed: () => app.catalog.refresh(force: true), child: const Text('Tentar de novo')),
                  ]),
                ),
              if (hero.isEmpty && cont.isEmpty && rows.every((r) => r.$2.isEmpty))
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Catálogo vazio. Conecte-se à internet uma vez para carregar o catálogo — depois ele fica salvo para uso offline.',
                      textAlign: TextAlign.center),
                ),
              if (cont.isNotEmpty)
                HRow('Continuar assistindo', [
                  for (final e in cont)
                    if (db.anime(e.animeId) != null)
                      Poster(
                        db.anime(e.animeId)!,
                        subtitle: e.label,
                        progress: e.durationMs > 0 ? e.positionMs / e.durationMs : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(episodeId: e.id))),
                      ),
                ]),
              for (final r in rows)
                if (r.$2.isNotEmpty)
                  HRow(r.$1, _posters(r.$2))
                else if (pref == 'dub' && r.$1.startsWith('Animes dublados'))
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                        'Nenhum episódio dublado ainda. Dentro de cada anime, use “Importar arquivos” (seus próprios arquivos dublados) ou “Fontes legais”.',
                        style: TextStyle(color: Colors.white60)),
                  ),
            ]),
          );
        },
      );
}

class HeroBanner extends StatefulWidget {
  const HeroBanner(this.items, {super.key});
  final List<Anime> items;
  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final pc = PageController();
  Timer? t;
  int cur = 0;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !pc.hasClients) return;
      pc.animateToPage((cur + 1) % widget.items.length, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    t?.cancel();
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    return SizedBox(
      height: wide ? 420 : 300,
      child: PageView.builder(
        controller: pc,
        itemCount: widget.items.length,
        onPageChanged: (i) => cur = i,
        itemBuilder: (_, i) {
          final a = widget.items[i];
          return Stack(fit: StackFit.expand, children: [
            img(a.bannerPath, a.banner),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF0B0B0F), Colors.transparent]),
              ),
            ),
            Positioned(
              left: 24, right: 24, bottom: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: wide ? 34 : 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(a.synopsis, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: () => openAnime(context, a.id), icon: const Icon(Icons.info_outline), label: const Text('Ver detalhes')),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
