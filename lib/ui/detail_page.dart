import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import '../services/archive.dart';
import '../services/importer.dart';
import 'episode_tile.dart';
import 'widgets.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.animeId});
  final int animeId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.db, app.settings]),
        builder: (context, _) {
          final a = app.db.anime(animeId);
          if (a == null) return const Scaffold(body: Center(child: Text('Anime não encontrado')));
          final filter = app.settings.langFilter;
          final eps = app.db.episodes(a.id).where((e) => langMatch(filter, e.lang)).toList();
          // dublado primeiro quando há mais de um idioma do mesmo episódio
          eps.sort((x, y) {
            final c = x.season != y.season ? x.season.compareTo(y.season) : x.number.compareTo(y.number);
            if (c != 0) return c;
            int r(String l) => l == 'dub' ? 0 : (l == 'multi' ? 1 : 2);
            return r(x.lang).compareTo(r(y.lang));
          });
          final seasons = <int, List<Episode>>{};
          for (final e in eps) {
            seasons.putIfAbsent(e.season, () => []).add(e);
          }
          final avail = app.db.episodes(a.id).map((e) => '${e.season}-${e.number}').toSet().length;
          return Scaffold(
            body: CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  background: Stack(fit: StackFit.expand, children: [
                    img(a.bannerPath.isNotEmpty ? a.bannerPath : a.coverPath, a.banner.isNotEmpty ? a.banner : a.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF0B0B0F), Colors.transparent]),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 12, children: [
                      if (a.year > 0) Text('${a.year}'),
                      if (a.score > 0) Text('★ ${a.score.toStringAsFixed(1)}'),
                      if (statusPt(a.status).isNotEmpty) Text(statusPt(a.status)),
                      Text(a.episodes > 0 ? '${a.episodes} episódios' : 'Episódios: ?'),
                      Text('$avail disponível(is)'),
                    ]),
                    if (a.genres.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.genres.replaceAll(',', ' • '), style: const TextStyle(color: Colors.white54))),
                    const SizedBox(height: 10),
                    Text(a.synopsis.isEmpty ? 'Sem sinopse.' : a.synopsis, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: () {
                          app.db.setFlag(a.id, 'in_list', !a.inList);
                          app.catalog.cacheOne(a);
                        },
                        icon: Icon(a.inList ? Icons.check : Icons.add),
                        label: const Text('Minha lista'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          app.db.setFlag(a.id, 'favorite', !a.favorite);
                          app.catalog.cacheOne(a);
                        },
                        icon: Icon(a.favorite ? Icons.favorite : Icons.favorite_border),
                        label: const Text('Favorito'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final m = await showDialog<String>(context: context, builder: (_) => _ArchiveDialog(a));
                          if (m != null && context.mounted) snack(context, m);
                        },
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Fontes legais'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _import(context, a),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Importar arquivos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (_) => _UrlDialog(a)),
                        icon: const Icon(Icons.link),
                        label: const Text('URL direta'),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'dub', label: Text('Dublado')),
                        ButtonSegment(value: 'sub', label: Text('Legendado')),
                        ButtonSegment(value: 'both', label: Text('Ambos')),
                      ],
                      selected: {filter},
                      onSelectionChanged: (s) => app.settings.set('lang', s.first),
                    ),
                  ]),
                ),
              ),
              if (eps.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum episódio com este filtro. Use “Fontes legais”, “Importar arquivos” ou “URL direta”.',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ),
              for (final s in seasons.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(children: [
                      Expanded(child: Text('Temporada ${s.key}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      TextButton.icon(
                        icon: const Icon(Icons.download_for_offline),
                        label: const Text('Baixar temporada'),
                        onPressed: () {
                          final ids = s.value.where((e) => !e.isDone && e.sourceUrl.isNotEmpty).map((e) => e.id);
                          final m = app.dl.enqueueAll(ids);
                          snack(context, m ?? (ids.isEmpty ? 'Nada para baixar nesta temporada.' : 'Downloads adicionados à fila.'));
                        },
                      ),
                    ]),
                  ),
                ),
                SliverList.builder(itemCount: s.value.length, itemBuilder: (_, i) => EpisodeTile(s.value[i])),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ]),
          );
        },
      );

  Future<void> _import(BuildContext context, Anime a) async {
    final cfg = await showDialog<({String lang, int season})>(context: context, builder: (_) => const _ImportCfg());
    if (cfg == null) return;
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'webm', 'avi', 'm4v', 'mov', 'ogv', 'ts'],
    );
    if (r == null) return;
    final paths = r.files.map((f) => f.path).whereType<String>().toList();
    if (context.mounted) snack(context, 'Importando ${paths.length} arquivo(s)…');
    final m = await Importer.importFiles(a, paths, cfg.lang, cfg.season);
    if (context.mounted) snack(context, m);
  }
}

class _ImportCfg extends StatefulWidget {
  const _ImportCfg();
  @override
  State<_ImportCfg> createState() => _ImportCfgState();
}

class _ImportCfgState extends State<_ImportCfg> {
  String lang = 'dub';
  int season = 1;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Importar arquivos'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Use apenas arquivos que você tem direito de usar. O número do episódio é lido do nome do arquivo (ex.: S01E03, EP03, “- 03”).',
              style: TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: lang,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'dub', child: Text('Dublado PT-BR')),
              DropdownMenuItem(value: 'sub', child: Text('Legendado')),
              DropdownMenuItem(value: 'multi', child: Text('Dub + Leg (várias faixas)')),
              DropdownMenuItem(value: 'unknown', child: Text('Não sei')),
            ],
            onChanged: (v) => setState(() => lang = v!),
          ),
          Row(children: [
            const Text('Temporada padrão: '),
            IconButton(onPressed: season > 1 ? () => setState(() => season--) : null, icon: const Icon(Icons.remove)),
            Text('$season'),
            IconButton(onPressed: () => setState(() => season++), icon: const Icon(Icons.add)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, (lang: lang, season: season)), child: const Text('Escolher arquivos')),
        ],
      );
}

class _UrlDialog extends StatefulWidget {
  const _UrlDialog(this.a);
  final Anime a;
  @override
  State<_UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<_UrlDialog> {
  final url = TextEditingController();
  final ep = TextEditingController(text: '1');
  final se = TextEditingController(text: '1');
  String lang = 'dub';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Baixar de URL direta'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Somente links de arquivos que você tem autorização para baixar.', style: TextStyle(fontSize: 12, color: Colors.white60)),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'URL do vídeo (https://…)')),
            Row(children: [
              Expanded(child: TextField(controller: se, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Temporada'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: ep, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Episódio'))),
            ]),
            DropdownButton<String>(
              value: lang,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'dub', child: Text('Dublado PT-BR')),
                DropdownMenuItem(value: 'sub', child: Text('Legendado')),
                DropdownMenuItem(value: 'multi', child: Text('Dub + Leg')),
                DropdownMenuItem(value: 'unknown', child: Text('Não sei')),
              ],
              onChanged: (v) => setState(() => lang = v!),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final u = url.text.trim();
              if (!u.startsWith('http')) return;
              final id = app.db.addEpisode(
                animeId: widget.a.id,
                season: int.tryParse(se.text) ?? 1,
                number: int.tryParse(ep.text) ?? 1,
                lang: lang,
                url: u,
              );
              final m = id < 0 ? 'Este episódio/idioma já existe.' : app.dl.enqueue(id);
              app.catalog.cacheOne(widget.a);
              Navigator.pop(context);
              if (m != null) snack(context, m);
            },
            child: const Text('Baixar'),
          ),
        ],
      );
}

class _ArchiveDialog extends StatefulWidget {
  const _ArchiveDialog(this.a);
  final Anime a;
  @override
  State<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends State<_ArchiveDialog> {
  late final q = TextEditingController(text: widget.a.title);
  List<SrcItem> items = [];
  List<SrcFile> files = [];
  final sel = <SrcFile>{};
  SrcItem? cur;
  String? note;
  bool busy = false;
  String lang = 'unknown';
  int season = 1;

  Future<void> search() async {
    setState(() {
      busy = true;
      note = null;
      cur = null;
    });
    try {
      items = await app.archive.search(q.text);
      if (items.isEmpty) note = 'Nada encontrado em fontes livres (Creative Commons / domínio público).';
    } catch (_) {
      note = 'Falha ao buscar. Verifique a internet.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> open(SrcItem it) async {
    setState(() => busy = true);
    try {
      final r = await app.archive.files(it.id);
      files = r.files;
      lang = r.lang;
      cur = it;
      sel.clear();
      if (files.isEmpty) note = 'Este item não tem arquivos de vídeo.';
    } catch (_) {
      note = 'Falha ao listar arquivos.';
    }
    if (mounted) setState(() => busy = false);
  }

  void add() {
    String? err;
    var n = 0;
    for (final f in sel) {
      n++;
      final r = Importer.parse(f.name, n, season);
      final id = app.db.addEpisode(
          animeId: widget.a.id, season: r.season, number: r.number, lang: lang, quality: f.quality, url: f.url, size: f.size);
      if (id > 0) err ??= app.dl.enqueue(id);
    }
    app.catalog.cacheOne(widget.a);
    Navigator.pop(context, err ?? 'Downloads adicionados à fila.');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Fontes legais (Internet Archive)'),
        content: SizedBox(
          width: 520,
          height: 440,
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: q, onSubmitted: (_) => search(), decoration: const InputDecoration(labelText: 'Buscar'))),
              IconButton(onPressed: search, icon: const Icon(Icons.search)),
            ]),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (note != null) Text(note!, style: const TextStyle(color: Colors.amber)),
            Expanded(
              child: cur == null
                  ? ListView(children: [
                      for (final it in items)
                        ListTile(
                          dense: true,
                          title: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(it.lang.isEmpty ? 'idioma não informado' : it.lang),
                          onTap: () => open(it),
                        ),
                    ])
                  : Column(children: [
                      Row(children: [
                        IconButton(onPressed: () => setState(() => cur = null), icon: const Icon(Icons.arrow_back)),
                        Expanded(child: Text(cur!.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        TextButton(onPressed: () => setState(() => sel.addAll(files)), child: const Text('Todos')),
                      ]),
                      Row(children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: lang,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'dub', child: Text('Áudio PT (dublado)')),
                              DropdownMenuItem(value: 'sub', child: Text('Legendado')),
                              DropdownMenuItem(value: 'multi', child: Text('Dub + Leg')),
                              DropdownMenuItem(value: 'unknown', child: Text('Idioma desconhecido')),
                            ],
                            onChanged: (v) => setState(() => lang = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('T$season'),
                        IconButton(onPressed: season > 1 ? () => setState(() => season--) : null, icon: const Icon(Icons.remove, size: 18)),
                        IconButton(onPressed: () => setState(() => season++), icon: const Icon(Icons.add, size: 18)),
                      ]),
                      Expanded(
                        child: ListView(children: [
                          for (final f in files)
                            CheckboxListTile(
                              dense: true,
                              value: sel.contains(f),
                              onChanged: (v) => setState(() => v! ? sel.add(f) : sel.remove(f)),
                              title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(f.quality),
                            ),
                        ]),
                      ),
                    ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          if (cur != null && sel.isNotEmpty) FilledButton(onPressed: add, child: Text('Baixar ${sel.length}')),
        ],
      );
}
