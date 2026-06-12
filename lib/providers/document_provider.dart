import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document.dart';
import '../models/tag.dart';
import '../models/association_tables.dart';
import '../database/daos/document_dao.dart';
import '../services/auto_tagging_service.dart';
import '../services/data_extraction_service.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentDao _documentDao = DocumentDao();
  final AutoTaggingService _autoTagging = AutoTaggingService();
  final DataExtractionService _extraction = DataExtractionService();
  final Uuid _uuid = const Uuid();

  List<Document> _documents = [];
  List<Document> get documents => _documents;

  Document? _selectedDocument;
  Document? get selectedDocument => _selectedDocument;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _documents = await _documentDao.getAll();
    } catch (e) {
      _error = 'Erreur chargement documents: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Document?> createDocument({
    required String title,
    String? filePath,
    String? mimeType,
    String? ocrText,
    DateTime? documentDate,
  }) async {
    _error = null;
    try {
      final doc = Document(
        id: _uuid.v4(),
        title: title,
        filePath: filePath,
        mimeType: mimeType,
        ocrText: ocrText,
        documentDate: documentDate,
      );

      await _documentDao.insert(doc);

      final tags = await _autoTagging.generateTags(doc.title, doc.ocrText);
      for (final tag in tags) {
        await _documentDao.addTag(DocumentTag(documentId: doc.id, tagId: tag.id));
      }

      await loadDocuments();
      return doc;
    } catch (e) {
      _error = 'Erreur création document: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateDocument(Document doc) async {
    try {
      await _documentDao.update(doc);
      await loadDocuments();
    } catch (e) {
      _error = 'Erreur mise à jour: $e';
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _documentDao.delete(id);
      await loadDocuments();
    } catch (e) {
      _error = 'Erreur suppression: $e';
      notifyListeners();
    }
  }

  Future<void> selectDocument(String id) async {
    try {
      _selectedDocument = await _documentDao.getById(id);
    } catch (e) {
      _error = 'Erreur sélection document: $e';
    }
    notifyListeners();
  }

  Future<List<Tag>> getTagsForDocument(String documentId) async {
    try {
      final tagMaps = await _documentDao.getTagsForDocument(documentId);
      return tagMaps.map((m) => Tag.fromMap(m)).toList();
    } catch (e) {
      _error = 'Erreur chargement tags: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> addTagToDocument(String documentId, Tag tag) async {
    try {
      await _documentDao.addTag(DocumentTag(documentId: documentId, tagId: tag.id));
      notifyListeners();
    } catch (e) {
      _error = 'Erreur ajout tag: $e';
      notifyListeners();
    }
  }

  Future<void> removeTagFromDocument(String documentId, String tagId) async {
    try {
      await _documentDao.removeTag(documentId, tagId);
      notifyListeners();
    } catch (e) {
      _error = 'Erreur suppression tag: $e';
      notifyListeners();
    }
  }

  ExtractedData extractData(String text) => _extraction.extractAll(text);

  Future<List<Document>> getRecent({int limit = 10}) async {
    try {
      return await _documentDao.getRecent(limit: limit);
    } catch (e) {
      _error = 'Erreur chargement récents: $e';
      notifyListeners();
      return [];
    }
  }
}
