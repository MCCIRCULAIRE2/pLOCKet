import '../database_helper.dart';
import '../../models/document.dart';
import '../../models/association_tables.dart';

class DocumentDao {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> insert(Document doc) async {
    final db = await _db.database;
    await db.insert('documents', doc.toMap());
  }

  Future<void> update(Document doc) async {
    final db = await _db.database;
    await db.update('documents', doc.toMap(), where: 'id = ?', whereArgs: [doc.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<Document?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  Future<List<Document>> getAll({String? orderBy = 'createdAt DESC'}) async {
    final db = await _db.database;
    final maps = await db.query('documents', orderBy: orderBy);
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<List<Document>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query(
      'documents',
      where: 'title LIKE ? OR ocrText LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<List<Document>> getRecent({int limit = 10}) async {
    final db = await _db.database;
    final maps = await db.query('documents', orderBy: 'createdAt DESC', limit: limit);
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<void> addTag(DocumentTag dt) async {
    final db = await _db.database;
    await db.insert('document_tags', dt.toMap());
  }

  Future<void> removeTag(String documentId, String tagId) async {
    final db = await _db.database;
    await db.delete('document_tags',
        where: 'documentId = ? AND tagId = ?', whereArgs: [documentId, tagId]);
  }

  Future<List<Map<String, dynamic>>> getTagsForDocument(String documentId) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN document_tags dt ON t.id = dt.tagId
      WHERE dt.documentId = ?
    ''', [documentId]);
  }

  Future<List<Document>> getByTagId(String tagId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT d.* FROM documents d
      INNER JOIN document_tags dt ON d.id = dt.documentId
      WHERE dt.tagId = ?
      ORDER BY d.createdAt DESC
    ''', [tagId]);
    return maps.map((m) => Document.fromMap(m)).toList();
  }
}
