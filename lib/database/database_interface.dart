abstract class IDatabase {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<void> insert(String table, Map<String, dynamic> values);

  Future<void> update(String table, Map<String, dynamic> values,
      {String? where, List<Object>? whereArgs});

  Future<void> delete(String table,
      {String? where, List<Object>? whereArgs});

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object>? arguments]);

  Future<void> execute(String sql, [List<Object>? arguments]);

  Future<void> close();
}
