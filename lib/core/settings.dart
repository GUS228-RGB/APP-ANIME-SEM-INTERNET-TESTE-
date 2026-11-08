import 'package:flutter/foundation.dart';
import 'db.dart';

class Settings extends ChangeNotifier {
  Settings(this.db);
  final Db db;

  /// dub | sub | both
  String get langFilter => db.kv('lang') ?? 'both';
  bool get autoplay => (db.kv('autoplay') ?? '1') == '1';
  int get countdown => int.tryParse(db.kv('countdown') ?? '') ?? 5;

  /// 0 = sem limite
  double get limitGb => double.tryParse(db.kv('limit_gb') ?? '') ?? 0;

  void set(String k, String v) {
    db.setKv(k, v);
    notifyListeners();
  }
}
