import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'core/app.dart';
import 'ui/downloads_page.dart';
import 'ui/home_page.dart';
import 'ui/library_page.dart';
import 'ui/search_page.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await app.init();
  runApp(const AnimeFlixApp());
}

class AnimeFlixApp extends StatelessWidget {
  const AnimeFlixApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AnimeFlix',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE50914), brightness: Brightness.dark, surface: const Color(0xFF0B0B0F)),
          scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  static const _dest = [
    (Icons.home_outlined, Icons.home, 'Início'),
    (Icons.search, Icons.search, 'Buscar'),
    (Icons.video_library_outlined, Icons.video_library, 'Biblioteca'),
    (Icons.download_outlined, Icons.download, 'Downloads'),
    (Icons.settings_outlined, Icons.settings, 'Config.'),
  ];

  Widget get page => switch (i) {
        0 => const HomePage(),
        1 => const SearchPage(),
        2 => const LibraryPage(),
        3 => const DownloadsPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('ANIMEFLIX',
                  style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            destinations: [
              for (final d in _dest)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          Expanded(child: page),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(bottom: false, child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: [
          for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
