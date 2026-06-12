import '../../database/database_helper.dart';
import '../../models/analytical_field.dart';

class AnalyticalFieldDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insertField(AnalyticalField field) async {
    final db = await _db.database;
    await db.insert('analytical_fields', field.toMap());
  }

  Future<void> updateField(AnalyticalField field) async {
    final db = await _db.database;
    await db.update('analytical_fields', field.toMap(),
        where: 'id = ?', whereArgs: [field.id]);
  }

  Future<void> deleteField(String id) async {
    final db = await _db.database;
    await db.delete('analytical_values',
        where: 'fieldId = ?', whereArgs: [id]);
    await db.delete('analytical_fields', where: 'id = ?', whereArgs: [id]);
  }

  Future<AnalyticalField?> getFieldById(String id) async {
    final db = await _db.database;
    final maps = await db.query('analytical_fields',
        where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AnalyticalField.fromMap(maps.first);
  }

  Future<List<AnalyticalField>> getAllFields() async {
    final db = await _db.database;
    final maps = await db.query('analytical_fields', orderBy: 'name');
    return maps.map((m) => AnalyticalField.fromMap(m)).toList();
  }

  Future<void> insertValue(AnalyticalValue value) async {
    final db = await _db.database;
    await db.insert('analytical_values', value.toMap());
  }

  Future<void> updateValue(AnalyticalValue value) async {
    final db = await _db.database;
    await db.update('analytical_values', value.toMap(),
        where: 'id = ?', whereArgs: [value.id]);
  }

  Future<void> deleteValue(String id) async {
    final db = await _db.database;
    await db.delete('analytical_values', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AnalyticalValue>> getValuesForField(String fieldId) async {
    final db = await _db.database;
    final maps = await db.query('analytical_values',
        where: 'fieldId = ?', whereArgs: [fieldId], orderBy: 'label');
    return maps.map((m) => AnalyticalValue.fromMap(m)).toList();
  }

  Future<List<AnalyticalValue>> getAllValues() async {
    final db = await _db.database;
    final maps = await db.query('analytical_values', orderBy: 'label');
    return maps.map((m) => AnalyticalValue.fromMap(m)).toList();
  }

  Future<List<AnalyticalValue>> searchValues(String query) async {
    final db = await _db.database;
    final maps = await db.query('analytical_values',
        where: 'label LIKE ? OR aliases LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'label');
    return maps.map((m) => AnalyticalValue.fromMap(m)).toList();
  }
}
