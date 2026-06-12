import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_interface.dart';
import 'persisted_memory_database.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  IDatabase? _database;

  Future<IDatabase> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<IDatabase> _initDatabase() async {
    debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');
    debugPrint('[DB INIT] Début initialisation base de données');
    debugPrint('[DB INIT] Plateforme: ${kIsWeb ? "Web" : defaultTargetPlatform.name}');
    debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');

    // Sur Web, utiliser PersistedMemoryDatabase (localStorage)
    if (kIsWeb) {
      debugPrint('[DB INIT] Mode Web — utilisation de PersistedMemoryDatabase');
      final db = PersistedMemoryDatabase();
      await db.init();
      await _createSchema(db);
      await _insertDefaultTags(db);
      debugPrint('[DB INIT] ✓ Base Web initialisée avec succès');
      return db;
    }

    // Sur desktop (Windows/Linux/macOS), utiliser sqflite_common_ffi
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint('[DB INIT] Initialisation FFI pour desktop...');
      sqfliteFfiInit();
      debugPrint('[DB INIT] ✓ FFI initialisé');
    }

    try {
      debugPrint('[DB INIT] Récupération du répertoire Documents...');
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = join(dir.path, 'plocket.db');
      debugPrint('[DB INIT] ✓ Répertoire: ${dir.path}');
      debugPrint('[DB INIT] Chemin base: $dbPath');
      debugPrint('[DB INIT] Ouverture de la base de données...');
      
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            debugPrint('[DB INIT] Création du schéma (version $version)...');
            await _onCreate(db, version);
            debugPrint('[DB INIT] ✓ Schéma créé');
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            debugPrint('[DB INIT] Migration v$oldVersion → v$newVersion...');
            await _onUpgrade(db, oldVersion, newVersion);
            debugPrint('[DB INIT] ✓ Migration terminée');
          },
        ),
      );

      debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');
      debugPrint('[DB INIT] ✓ Base de données ouverte avec succès');
      debugPrint('[DB INIT] Chemin: $dbPath');
      debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');
      return _SqfliteAdapter(db);
    } catch (e, stackTrace) {
      debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');
      debugPrint('[DB INIT] ❌ ERREUR CRITIQUE lors de l\'ouverture de la base');
      debugPrint('[DB INIT] Erreur: $e');
      debugPrint('[DB INIT] Stack trace:\n$stackTrace');
      debugPrint('[DB INIT] ═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(_SqfliteAdapter(db));
    await _insertDefaultTags(_SqfliteAdapter(db));
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final adapter = _SqfliteAdapter(db);
    if (oldVersion < 2) {
      await adapter.execute('ALTER TABLE documents ADD COLUMN sourceData TEXT');
    }
    if (oldVersion < 3) {
      await adapter.execute('''
        CREATE TABLE IF NOT EXISTS analytical_fields (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await adapter.execute('''
        CREATE TABLE IF NOT EXISTS analytical_values (
          id TEXT PRIMARY KEY,
          fieldId TEXT NOT NULL,
          label TEXT NOT NULL,
          aliases TEXT,
          identifiers TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _createSchema(IDatabase db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        filePath TEXT,
        mimeType TEXT,
        ocrText TEXT,
        sourceData TEXT,
        createdAt TEXT NOT NULL,
        documentDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_tags (
        documentId TEXT NOT NULL,
        tagId TEXT NOT NULL,
        PRIMARY KEY (documentId, tagId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        name TEXT NOT NULL,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_entities (
        documentId TEXT NOT NULL,
        entityId TEXT NOT NULL,
        PRIMARY KEY (documentId, entityId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        eventType TEXT NOT NULL,
        entityId TEXT,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        metadata TEXT,
        documentId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS procedures (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS procedure_documents (
        procedureId TEXT NOT NULL,
        documentId TEXT NOT NULL,
        PRIMARY KEY (procedureId, documentId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        subType TEXT NOT NULL,
        rawText TEXT NOT NULL,
        value TEXT,
        date TEXT,
        fields TEXT,
        tags TEXT,
        sourceDocumentId TEXT,
        filePath TEXT,
        mimeType TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS analytical_fields (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS analytical_values (
        id TEXT PRIMARY KEY,
        fieldId TEXT NOT NULL,
        label TEXT NOT NULL,
        aliases TEXT,
        identifiers TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertDefaultTags(IDatabase db) async {
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM tags');
    if (result.isNotEmpty && (result.first['cnt'] as int? ?? 0) > 0) {
      return;
    }

    final tags = [
      {'id': 'type_facture', 'label': 'Facture', 'category': 'type'},
      {'id': 'type_contrat', 'label': 'Contrat', 'category': 'type'},
      {'id': 'type_attestation', 'label': 'Attestation', 'category': 'type'},
      {'id': 'type_identite', 'label': 'Identité', 'category': 'type'},
      {'id': 'type_bulletin', 'label': 'Bulletin de salaire', 'category': 'type'},
      {'id': 'type_courrier', 'label': 'Courrier', 'category': 'type'},
      {'id': 'domaine_automobile', 'label': 'Automobile', 'category': 'domain'},
      {'id': 'domaine_habitation', 'label': 'Habitation', 'category': 'domain'},
      {'id': 'domaine_sante', 'label': 'Santé', 'category': 'domain'},
      {'id': 'domaine_banque', 'label': 'Banque', 'category': 'domain'},
      {'id': 'domaine_fiscalite', 'label': 'Fiscalité', 'category': 'domain'},
      {'id': 'domaine_travail', 'label': 'Travail', 'category': 'domain'},
      {'id': 'sousdomaine_assurance', 'label': 'Assurance', 'category': 'subdomain'},
      {'id': 'sousdomaine_entretien', 'label': 'Entretien', 'category': 'subdomain'},
      {'id': 'sousdomaine_credit', 'label': 'Crédit', 'category': 'subdomain'},
      {'id': 'sousdomaine_garantie', 'label': 'Garantie', 'category': 'subdomain'},
      {'id': 'statut_actif', 'label': 'Actif', 'category': 'status'},
      {'id': 'statut_expire', 'label': 'Expiré', 'category': 'status'},
      {'id': 'statut_resilie', 'label': 'Résilié', 'category': 'status'},
    ];
    for (final tag in tags) {
      await db.insert('tags', Map<String, dynamic>.from(tag));
    }
  }
}

class _SqfliteAdapter implements IDatabase {
  final Database _db;

  _SqfliteAdapter(this._db);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    debugPrint('[DB READ] Query sur table "$table" (where: $where)');
    try {
      final result = await _db.query(table,
          columns: columns,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy,
          limit: limit);
      debugPrint('[DB READ] ✓ ${result.length} ligne(s) retournée(s)');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[DB READ] ❌ ERREUR query sur "$table": $e');
      debugPrint('[DB READ] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> values) async {
    debugPrint('[DB WRITE] Insert dans "$table" (id: ${values['id']})');
    try {
      await _db.insert(table, values,
          conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[DB WRITE] ✓ Insert réussi');
    } catch (e, stackTrace) {
      debugPrint('[DB WRITE] ❌ ERREUR insert dans "$table": $e');
      debugPrint('[DB WRITE] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> update(String table, Map<String, dynamic> values,
      {String? where, List<Object>? whereArgs}) async {
    debugPrint('[DB WRITE] Update dans "$table" (where: $where)');
    try {
      await _db.update(table, values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('[DB WRITE] ✓ Update réussi');
    } catch (e, stackTrace) {
      debugPrint('[DB WRITE] ❌ ERREUR update dans "$table": $e');
      debugPrint('[DB WRITE] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> delete(String table,
      {String? where, List<Object>? whereArgs}) async {
    debugPrint('[DB WRITE] Delete dans "$table" (where: $where)');
    try {
      await _db.delete(table, where: where, whereArgs: whereArgs);
      debugPrint('[DB WRITE] ✓ Delete réussi');
    } catch (e, stackTrace) {
      debugPrint('[DB WRITE] ❌ ERREUR delete dans "$table": $e');
      debugPrint('[DB WRITE] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object>? arguments]) async {
    debugPrint('[DB READ] RawQuery: ${sql.substring(0, sql.length > 80 ? 80 : sql.length)}...');
    try {
      final result = await _db.rawQuery(sql, arguments);
      debugPrint('[DB READ] ✓ ${result.length} ligne(s) retournée(s)');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[DB READ] ❌ ERREUR rawQuery: $e');
      debugPrint('[DB READ] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> execute(String sql, [List<Object>? arguments]) async {
    debugPrint('[DB WRITE] Execute: ${sql.substring(0, sql.length > 80 ? 80 : sql.length)}...');
    try {
      await _db.execute(sql, arguments);
      debugPrint('[DB WRITE] ✓ Execute réussi');
    } catch (e, stackTrace) {
      debugPrint('[DB WRITE] ❌ ERREUR execute: $e');
      debugPrint('[DB WRITE] Stack: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    debugPrint('[DB] Fermeture de la base de données...');
    await _db.close();
    debugPrint('[DB] ✓ Base fermée');
  }
}
