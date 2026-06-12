import '../database_helper.dart';
import '../../models/tag.dart';

class TagDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(Tag tag) async {
    final db = await _db.database;
    await db.insert('tags', tag.toMap());
  }

  Future<Tag?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  Future<List<Tag>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('tags', orderBy: 'category, label');
    return maps.map((m) => Tag.fromMap(m)).toList();
  }

  Future<List<Tag>> getByCategory(TagCategory category) async {
    final db = await _db.database;
    final maps = await db.query('tags',
        where: 'category = ?', whereArgs: [category.name], orderBy: 'label');
    return maps.map((m) => Tag.fromMap(m)).toList();
  }

  Future<List<Tag>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query('tags',
        where: 'label LIKE ?', whereArgs: ['%$query%'], orderBy: 'label');
    return maps.map((m) => Tag.fromMap(m)).toList();
  }
}
