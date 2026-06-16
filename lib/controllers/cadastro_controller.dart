import 'package:flutter/foundation.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart' as storage;
import '../utils/id.dart';

/// Controller da tela de Cadastro de produtos.
///
/// Mantém a lista de locais ativos (para o seletor) e cria novos produtos.
class CadastroController extends ChangeNotifier {
  List<Local> locais = [];

  CadastroController() {
    storage.dataChanged.addListener(_onDataChanged);
  }

  void _onDataChanged() => load();

  @override
  void dispose() {
    storage.dataChanged.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> load() async {
    locais = await storage.getLocaisAtivos();
    notifyListeners();
  }

  Future<void> addProduto({
    required String localId,
    required String localNome,
    required int quantidade,
    required String nome,
    required String validade,
    required String situacao,
    required String status,
  }) async {
    await storage.addProduto(
      Produto(
        id: generateId(),
        localId: localId,
        localNome: localNome,
        quantidade: quantidade,
        nome: nome,
        validade: validade,
        situacao: situacao,
        status: status,
      ),
    );
  }
}
