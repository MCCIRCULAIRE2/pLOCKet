import '../database_helper.dart';
import '../../models/card_model.dart';

class CardDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(CardModel card) async {
    final db = await _db.database;
    await db.insert('cards', card.toMap());
  }

  Future<void> update(CardModel card) async {
    final db = await _db.database;
    await db.update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<CardModel?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('cards', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return CardModel.fromMap(maps.first);
  }

  Future<List<CardModel>> getAll({String? orderBy = 'createdAt DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('cards', orderBy: orderBy);
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }

  Future<List<CardModel>> getByType(CardType type,
      {String? orderBy = 'createdAt DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('cards',
        where: 'type = ?', whereArgs: [type.name], orderBy: orderBy);
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }

  Future<List<CardModel>> getBySubType(String subType,
      {String? orderBy = 'createdAt DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('cards',
        where: 'subType = ?', whereArgs: [subType], orderBy: orderBy);
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }

  Future<List<CardModel>> getRecent({int limit = 10}) async {
    final db = await _db.database;
    final maps = await db.query('cards', orderBy: 'createdAt DESC', limit: limit);
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }

  Future<List<CardModel>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query('cards',
        where:
            'title LIKE ? OR rawText LIKE ? OR tags LIKE ? OR value LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
        orderBy: 'createdAt DESC');
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }

  Future<List<CardModel>> getByTag(String tag) async {
    final db = await _db.database;
    final maps = await db.query('cards',
        where: 'tags LIKE ?', whereArgs: ['%$tag%'], orderBy: 'createdAt DESC');
    return maps.map((m) => CardModel.fromMap(m)).toList();
  }
}
