import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_database.dart';

/// Base de données en mémoire persistée via SharedPreferences (localStorage sur Web)
class PersistedMemoryDatabase extends MemoryDatabase {
  static const String _storageKey = 'plocket_db';

  @override
  Future<void> init() async {
    print('[STORAGE INIT] ═══════════════════════════════════════════════════════════');
    print('[STORAGE INIT] Type de stockage: SharedPreferences (localStorage sur Web)');
    print('[STORAGE INIT] Clé de stockage: $_storageKey');
    print('[STORAGE INIT] ═══════════════════════════════════════════════════════════');
    await _load();
  }

  Future<void> _load() async {
    print('[LOAD] ═══════════════════════════════════════════════════════════');
    print('[LOAD] Début chargement des données');
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      
      if (data != null && data.isNotEmpty) {
        print('[LOAD] ✓ Données trouvées dans localStorage (${data.length} caractères)');
        final Map<String, dynamic> decoded = jsonDecode(data);
        
        int totalRows = 0;
        for (final entry in decoded.entries) {
          final tableName = entry.key;
          final rows = (entry.value as List).cast<Map<String, dynamic>>();
          tables[tableName] = rows;
          totalRows += rows.length;
          print('[LOAD]   Table "$tableName": ${rows.length} ligne(s)');
        }
        
        print('[LOAD] ✓ Base chargée: ${decoded.length} tables, $totalRows lignes au total');
      } else {
        print('[LOAD] ⚠ Aucune donnée trouvée dans localStorage');
        print('[LOAD]   C\'est normal si c\'est la première utilisation');
      }
    } catch (e, stackTrace) {
      print('[STORAGE ERROR] ═══════════════════════════════════════════════════════════');
      print('[STORAGE ERROR] ❌ Erreur lors du chargement: $e');
      print('[STORAGE ERROR] Stack trace:\n$stackTrace');
      print('[STORAGE ERROR] ═══════════════════════════════════════════════════════════');
    }
    print('[LOAD] ═══════════════════════════════════════════════════════════');
  }

  Future<void> _save() async {
    print('[SAVE] ═══════════════════════════════════════════════════════════');
    print('[SAVE] Début sauvegarde des données');
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(tables);
      
      int totalRows = 0;
      for (final entry in tables.entries) {
        totalRows += entry.value.length;
        print('[SAVE]   Table "${entry.key}": ${entry.value.length} ligne(s)');
      }
      
      await prefs.setString(_storageKey, data);
      print('[SAVE] ✓ Données sauvegardées: ${tables.length} tables, $totalRows lignes (${data.length} caractères)');
    } catch (e, stackTrace) {
      print('[STORAGE ERROR] ═══════════════════════════════════════════════════════════');
      print('[STORAGE ERROR] ❌ Erreur lors de la sauvegarde: $e');
      print('[STORAGE ERROR] Stack trace:\n$stackTrace');
      print('[STORAGE ERROR] ═══════════════════════════════════════════════════════════');
    }
    print('[SAVE] ═══════════════════════════════════════════════════════════');
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
