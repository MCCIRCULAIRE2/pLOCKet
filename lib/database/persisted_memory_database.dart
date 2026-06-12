import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_database.dart';

/// Base de données en mémoire persistée via SharedPreferences (localStorage sur Web)
class PersistedMemoryDatabase extends MemoryDatabase {
  static const String _storageKey = 'plocket_db';

  @override
  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        for (final entry in decoded.entries) {
          final tableName = entry.key;
          final rows = (entry.value as List).cast<Map<String, dynamic>>();
          tables[tableName] = rows;
        }
        print('[DB LOAD] ✓ Base chargée depuis localStorage (${decoded.length} tables)');
      }
    } catch (e, stackTrace) {
      print('[DB LOAD] ❌ Erreur chargement: $e');
      print('[DB LOAD] Stack: $stackTrace');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(tables);
      await prefs.setString(_storageKey, data);
    } catch (e, stackTrace) {
      print('[DB SAVE] ❌ Erreur sauvegarde: $e');
      print('[DB SAVE] Stack: $stackTrace');
    }
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> values) async {
    await super.insert(table, values);
    await _save();
  }

  @override
  Future<void> update(String table, Map<String, dynamic> values,
      {String? where, List<Object>? whereArgs}) async {
    await super.update(table, values, where: where, whereArgs: whereArgs);
    await _save();
  }

  @override
  Future<void> delete(String table, {String? where, List<Object>? whereArgs}) async {
    await super.delete(table, where: where, whereArgs: whereArgs);
    await _save();
  }

  @override
  Future<void> execute(String sql, [List<Object>? arguments]) async {
    await super.execute(sql, arguments);
    await _save();
  }
}
