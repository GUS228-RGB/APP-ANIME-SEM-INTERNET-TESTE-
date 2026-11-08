import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import 'episode_tile.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.db,
        builder: (context, _) {
          final rows = app.db.q('''
            SELECT e.*, a.title AS atitle FROM episode e JOIN anime a ON a.id=e.anime_id
            WHERE e.status IN ('queued','downloading','paused','error','done')
            ORDER BY CASE e.status WHEN 'downloading' THEN 0 WHEN 'queued' THEN 1 WHEN 'paused' THEN 2 WHEN 'error' THEN 3 ELSE 4 END,
                     a.title, e.season, e.number''');
          final used = app.db.usedBytes();
          final limit = app.settings.limitGb;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Armazenamento: ${fmtBytes(used)}${limit > 0 ? ' de ${limit.toStringAsFixed(0)} GB' : ' (sem limite)'}'),
                if (limit > 0) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: (used / (limit * 1e9)).clamp(0, 1).toDouble())),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Nenhum download.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) => EpisodeTile(Episode.fromRow(rows[i]), animeTitle: rows[i]['atitle'] as String?),
                    ),
            ),
          ]);
        },
      );
}
