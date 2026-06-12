import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/procedure.dart';
import '../database/daos/procedure_dao.dart';

class ProcedureProvider extends ChangeNotifier {
  final ProcedureDao _procedureDao = ProcedureDao();
  final Uuid _uuid = const Uuid();

  List<Procedure> _procedures = [];
  List<Procedure> get procedures => _procedures;

  Future<void> loadProcedures() async {
    _procedures = await _procedureDao.getAll();
    notifyListeners();
  }

  Future<Procedure> createProcedure({
    required String title,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final procedure = Procedure(
      id: _uuid.v4(),
      title: title,
      description: description,
      metadata: metadata,
    );
    await _procedureDao.insert(procedure);
    await loadProcedures();
    return procedure;
  }
}
