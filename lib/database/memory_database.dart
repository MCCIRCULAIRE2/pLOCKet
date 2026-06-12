import 'database_interface.dart';

/// Base de données en mémoire pure (non persistante)
class MemoryDatabase implements IDatabase {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  Future<void> init() async {
    // Par défaut, rien à faire
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final tableData = tables[table] ?? [];
    var results = List<Map<String, dynamic>>.from(tableData);

    // Appliquer le filtre WHERE
    if (where != null && whereArgs != null) {
      results = results.where((row) => _matchesWhere(row, where, whereArgs)).toList();
    }

    // Appliquer le tri
    if (orderBy != null) {
      final parts = orderBy.split(' ');
      final column = parts[0];
      final descending = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      
      results.sort((a, b) {
        final aVal = a[column];
        final bVal = b[column];
        if (aVal == null && bVal == null) return 0;
        if (aVal == null) return descending ? 1 : -1;
        if (bVal == null) return descending ? -1 : 1;
        
        final comparison = aVal.compareTo(bVal);
        return descending ? -comparison : comparison;
      });
    }

    // Appliquer limit
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> values) async {
    tables.putIfAbsent(table, () => []);
    tables[table]!.add(Map<String, dynamic>.from(values));
  }

  @override
  Future<void> update(String table, Map<String, dynamic> values,
      {String? where, List<Object>? whereArgs}) async {
    final tableData = tables[table] ?? [];

    for (int i = 0; i < tableData.length; i++) {
      if (where == null || whereArgs == null || _matchesWhere(tableData[i], where, whereArgs)) {
        tableData[i] = {...tableData[i], ...values};
      }
    }
  }

  @override
  Future<void> delete(String table, {String? where, List<Object>? whereArgs}) async {
    final tableData = tables[table] ?? [];

    if (where == null || whereArgs == null) {
      tables[table] = [];
      return;
    }

    tables[table] = tableData.where((row) => !_matchesWhere(row, where, whereArgs)).toList();
  }

  @override
  Future<void> execute(String sql, [List<Object>? arguments]) async {
    // Pour les CREATE TABLE, on ne fait rien car les tables sont créées à la volée
    // Pour les autres opérations SQL, on pourrait les parser mais ce n'est pas nécessaire pour l'instant
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object>? arguments]) async {
    // Parser basique pour COUNT(*)
    if (sql.toUpperCase().contains('COUNT(*)')) {
      final tableMatch = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(sql);
      if (tableMatch != null) {
        final tableName = tableMatch.group(1)!;
        final count = tables[tableName]?.length ?? 0;
        return [{'COUNT(*)': count}];
      }
    }

    // Pour les autres requêtes, retourner vide
    return [];
  }

  @override
  Future<void> close() async {
    // Rien à faire pour une base en mémoire
  }

  bool _matchesWhere(Map<String, dynamic> row, String where, List<Object> whereArgs) {
    // Parser basique pour "column = ?"
    final parts = where.split('=');
    if (parts.length == 2) {
      final column = parts[0].trim();
      final value = whereArgs.isNotEmpty ? whereArgs[0] : null;
      return row[column] == value;
    }
    return false;
  }
}
