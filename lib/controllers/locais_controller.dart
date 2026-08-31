import 'package:flutter/foundation.dart';
import '../models/local.dart';
import '../storage/storage.dart' as storage;
import '../utils/id.dart';

/// Controller da tela de Locais: carregamento e CRUD dos locais.
class LocaisController extends ChangeNotifier {
  List<Local> locais = [];

  LocaisController() {
    storage.dataChanged.addListener(_onDataChanged);
  }

  void _onDataChanged() => load();

  @override
  void dispose() {
    storage.dataChanged.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> load() async {
    final data = await storage.getLocais();
    locais = data;
    notifyListeners();
  }

  Future<void> save({
    String? id,
    required String nome,
    required bool ativo,
  }) async {
    if (id != null) {
      await storage.updateLocal(Local(id: id, nome: nome, ativo: ativo));
    } else {
      await storage.addLocal(Local(id: generateId(), nome: nome, ativo: ativo));
    }
    await load();
  }

  Future<void> delete(String id) async {
    await storage.deleteLocal(id);
    await load();
  }
}
