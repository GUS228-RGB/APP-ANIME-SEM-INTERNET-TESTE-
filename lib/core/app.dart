import '../services/anilist.dart';
import '../services/archive.dart';
import '../services/catalog.dart';
import '../services/downloader.dart';
import 'db.dart';
import 'settings.dart';

class Services {
  final db = Db();
  late final Settings settings;
  late final AniList api;
  late final Catalog catalog;
  late final Downloader dl;
  late final ArchiveSource archive;

  Future<void> init() async {
    await db.init();
    settings = Settings(db);
    api = AniList();
    catalog = Catalog(db, api);
    dl = Downloader(db, settings);
    archive = ArchiveSource();
    dl.recover();
  }
}

final app = Services();
