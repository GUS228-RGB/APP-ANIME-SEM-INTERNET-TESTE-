import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/app.dart';
import '../core/models.dart';
import '../services/backup.dart';
import 'episode_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext c) async {
    final bytes = Uint8List.fromList(utf8.encode(Backup.dump()));
    final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar progresso', fileName: 'animeflix_progresso.json', bytes: bytes);
    if (path != null && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      await File(path).writeAsBytes(bytes);
    }
    if (c.mounted && path != null) snack(c, 'Progresso exportado.');
  }

  Future<void> _import(BuildContext c) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final p = r?.files.single.path;
    if (p == null) return;
    try {
      final m = Backup.restore(await File(p).readAsString());
      if (c.mounted) snack(c, m);
    } catch (_) {
      if (c.mounted) snack(c, 'Arquivo inválido.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.settings,
        builder: (context, _) {
          final s = app.settings;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Idioma preferido', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dub', label: Text('Dublado')),
                ButtonSegment(value: 'sub', label: Text('Legendado')),
                ButtonSegment(value: 'both', label: Text('Ambos')),
              ],
              selected: {s.langFilter},
              onSelectionChanged: (v) => s.set('lang', v.first),
            ),
            const Divider(height: 32),
            SwitchListTile(
              title: const Text('Reprodução automática (autoplay)'),
              subtitle: const Text('Inicia o próximo episódio sozinho'),
              value: s.autoplay,
              onChanged: (v) => s.set('autoplay', v ? '1' : '0'),
            ),
            ListTile(
              title: Text('Contagem regressiva: ${s.countdown}s'),
              subtitle: Slider(
                value: s.countdown.toDouble().clamp(0, 15).toDouble(),
                min: 0,
                max: 15,
                divisions: 15,
                onChanged: (v) => s.set('countdown', '${v.round()}'),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              title: Text(s.limitGb > 0 ? 'Limite de downloads: ${s.limitGb.toStringAsFixed(0)} GB' : 'Limite de downloads: sem limite'),
              subtitle: Slider(
                value: s.limitGb.clamp(0, 200).toDouble(),
                min: 0,
                max: 200,
                divisions: 40,
                onChanged: (v) => s.set('limit_gb', '${v.round()}'),
              ),
            ),
            Text('Em uso: ${fmtBytes(app.db.usedBytes())}', style: const TextStyle(color: Colors.white60)),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Atualizar catálogo agora'),
              onTap: () {
                app.catalog.refresh(force: true);
                snack(context, 'Atualizando catálogo…');
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Exportar lista e progresso'),
              subtitle: const Text('Gera um arquivo para levar a outro dispositivo'),
              onTap: () => _export(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('Importar lista e progresso'),
              onTap: () => _import(context),
            ),
            const Divider(height: 32),
            const Text(
              'AnimeFlix 1.0 · Catálogo: AniList · Fontes de download: Internet Archive (conteúdo livre) e arquivos/URLs que você tem direito de usar.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]);
        },
      );
}
