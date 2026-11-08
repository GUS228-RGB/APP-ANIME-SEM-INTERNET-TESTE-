import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import 'player_page.dart';
import 'widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  static const _tabs = ['Continuar', 'Minha lista', 'Favoritos', 'Histórico', 'Baixados', 'Concluídos', 'Em andamento'];

  /// Concluído = todos os episódios do anime (ou os baixados, se o total for desconhecido) já foram vistos.
  List<Anime> _byProgress(bool completed) {
    final out = <Anime>[];
    for (final a in app.db.downloadedAnimes()) {
      final done = app.db.episodes(a.id).where((e) => e.isDone).toList();
      final all = done.map((e) => '${e.season}-${e.number}').toSet();
      final seen = done.where((e) => e.watched).map((e) => '${e.season}-${e.number}').toSet();
      final touched = seen.isNotEmpty || done.any((e) => e.positionMs > 0);
      final total = a.episodes > 0 ? a.episodes : all.length;
      final finished = total > 0 && seen.length >= total;
      if (completed ? finished : (touched && !finished)) out.add(a);
    }
    return out;
  }

  Widget _grid(List<Anime> l, String empty) => l.isEmpty
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54))))
      : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170, childAspectRatio: .5, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: l.length,
          itemBuilder: (_, i) => Poster(l[i]),
        );

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.day)}/${t(d.month)} ${t(d.hour)}:${t(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: _tabs.length,
        child: Column(children: [
          TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in _tabs) Tab(text: t)]),
          Expanded(
            child: ListenableBuilder(
              listenable: app.db,
              builder: (context, _) {
                final db = app.db;
                final cont = db.continueWatching();
                final hist = db.history();
                return TabBarView(children: [
                  cont.isEmpty
                      ? const Center(child: Text('Nada em andamento.', style: TextStyle(color: Colors.white54)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 170, childAspectRatio: .5, crossAxisSpacing: 12, mainAxisSpacing: 12),
                          itemCount: cont.length,
                          itemBuilder: (_, i) {
                            final e = cont[i];
                            final a = db.anime(e.animeId);
                            if (a == null) return const SizedBox.shrink();
                            return Poster(a,
                                subtitle: e.label,
                                progress: e.durationMs > 0 ? e.positionMs / e.durationMs : null,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(episodeId: e.id))));
                          },
                        ),
                  _grid(db.animes('in_list=1 ORDER BY title'), 'Sua lista está vazia.'),
                  _grid(db.animes('favorite=1 ORDER BY title'), 'Nenhum favorito.'),
                  hist.isEmpty
                      ? const Center(child: Text('Histórico vazio.', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: hist.length,
                          itemBuilder: (_, i) {
                            final e = hist[i];
                            final a = db.anime(e.animeId);
                            return ListTile(
                              leading: a == null ? null : SizedBox(width: 40, child: img(a.coverPath, a.cover)),
                              title: Text('${a?.title ?? 'Anime'} · ${e.label}'),
                              subtitle: Text(_date(e.lastWatched)),
                              trailing: LangBadge(e.lang),
                              onTap: e.isDone
                                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(episodeId: e.id)))
                                  : null,
                            );
                          },
                        ),
                  _grid(db.downloadedAnimes(), 'Nenhum episódio baixado ainda.'),
                  _grid(_byProgress(true), 'Nenhum anime concluído.'),
                  _grid(_byProgress(false), 'Nenhum anime em andamento.'),
                ]);
              },
            ),
          ),
        ]),
      );
}
