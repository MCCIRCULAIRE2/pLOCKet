import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/daos/card_dao.dart';
import '../services/cloud_repository.dart';

class DataMigrationService {
  static const String _cardsMigratedKey = 'cards_migrated_to_cloud';

  final CardDao _cardDao = CardDao();
  final CloudRepository _cloudRepo = CloudRepository();

  Future<bool> isCardsMigrationDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cardsMigratedKey) ?? false;
  }

  Future<MigrationResult> migrateCardsToCloud() async {
    final result = MigrationResult();

    try {
      if (await isCardsMigrationDone()) {
        debugPrint('[MIGRATION] Cards already migrated, skipping');
        result.skipped = true;
        return result;
      }

      debugPrint('[MIGRATION] ═══════════════════════════════════════════════════════════');
      debugPrint('[MIGRATION] Starting SQLite → Cloud migration for cards');
      debugPrint('[MIGRATION] ═══════════════════════════════════════════════════════════');

      final localCards = await _cardDao.getAll();
      debugPrint('[MIGRATION] Found ${localCards.length} cards in SQLite');

      if (localCards.isEmpty) {
        debugPrint('[MIGRATION] No cards to migrate');
        await _markMigrationDone();
        result.skipped = true;
        return result;
      }

      int successCount = 0;
      int errorCount = 0;

      for (final card in localCards) {
        try {
          debugPrint('[MIGRATION] Migrating card: ${card.title} (${card.id})');
          await _cloudRepo.insertCard(card);
          successCount++;
          debugPrint('[MIGRATION] ✓ Card migrated: ${card.title}');
        } catch (e) {
          errorCount++;
          debugPrint('[MIGRATION] ❌ Error migrating card ${card.id}: $e');
          result.errors.add('Card ${card.id}: $e');
        }
      }

      result.migrated = successCount;
      result.failed = errorCount;

      if (errorCount == 0) {
        await _markMigrationDone();
        debugPrint('[MIGRATION] ✓ All cards migrated successfully');
      } else {
        debugPrint('[MIGRATION] ⚠ Migration completed with $errorCount errors');
      }

      debugPrint('[MIGRATION] ═══════════════════════════════════════════════════════════');
      debugPrint('[MIGRATION] Result: $successCount migrated, $errorCount failed');
      debugPrint('[MIGRATION] ═══════════════════════════════════════════════════════════');

    } catch (e) {
      debugPrint('[MIGRATION] ❌ Fatal error: $e');
      result.errors.add('Fatal: $e');
    }

    return result;
  }

  Future<void> _markMigrationDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cardsMigratedKey, true);
    debugPrint('[MIGRATION] Migration flag set in SharedPreferences');
  }

  Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cardsMigratedKey);
    debugPrint('[MIGRATION] Migration flag reset');
  }
}

class MigrationResult {
  int migrated = 0;
  int failed = 0;
  bool skipped = false;
  List<String> errors = [];

  bool get success => failed == 0 && !skipped;
}
