import 'package:flutter/foundation.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart' as storage;
import '../utils/date_utils.dart' as du;

/// Base dos controllers das telas que listam produtos (Produtos e Exportar).
///
/// Concentra o carregamento de dados, ordenação, filtro por local e as
/// operações de CRUD, deixando para as subclasses apenas as regras de filtro
/// específicas de cada tela (getter [filtered]).
abstract class BaseProdutoController extends ChangeNotifier {
  List<Produto> produtos = [];
  List<Local> locais = [];
  final List<String> filtrosLocal = [];
  String sortField = 'validade';
  bool sortAsc = true;
  bool loading = true;

  BaseProdutoController() {
    storage.dataChanged.addListener(_onDataChanged);
  }

  void _onDataChanged() => load();

  @override
  void dispose() {
    storage.dataChanged.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> load() async {
    if (produtos.isEmpty) {
      loading = true;
      notifyListeners();
    }
    final prods = await storage.getProdutos();
    final locs = await storage.getLocais();
    produtos = prods;
    locais = locs;
    loading = false;
    notifyListeners();
  }

  List<Local> get locaisAtivos => locais.where((l) => l.ativo).toList();

  bool isLocalAtivo(Produto p) {
    for (final l in locais) {
      if (l.id == p.localId) return l.ativo;
    }
    for (final l in locais) {
      if (l.nome.toLowerCase() == p.localNome.toLowerCase()) return l.ativo;
    }
    return false;
  }

  bool matchesLocalFilter(Produto p) {
    if (filtrosLocal.isEmpty) return true;
    return filtrosLocal.any(
      (f) => p.localNome.toLowerCase() == f.toLowerCase(),
    );
  }

  /// Regras de filtro específicas de cada tela.
  List<Produto> get filtered;

  int _compare(Produto a, Produto b) {
    switch (sortField) {
      case 'local':
        return a.localNome.compareTo(b.localNome);
      case 'qtd':
        return a.quantidade.compareTo(b.quantidade);
      case 'produto':
        return a.nome.compareTo(b.nome);
      case 'situacao':
        return a.situacao.compareTo(b.situacao);
      case 'status':
        return a.status.compareTo(b.status);
      default:
        return du.compareDates(a.validade, b.validade);
    }
  }

  List<Produto> get sorted {
    final list = List<Produto>.from(filtered);
    list.sort((a, b) {
      final cmp = _compare(a, b);
      return sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void toggleSort(String field) {
    if (sortField == field) {
      sortAsc = !sortAsc;
    } else {
      sortField = field;
      sortAsc = true;
    }
    notifyListeners();
  }

  String sortArrow(String field) =>
      sortField == field ? (sortAsc ? ' ▲' : ' ▼') : '';

  void toggleLocalFilter(String nome) {
    if (filtrosLocal.contains(nome)) {
      filtrosLocal.remove(nome);
    } else {
      filtrosLocal.add(nome);
    }
    notifyListeners();
  }

  void clearLocalFilters() {
    filtrosLocal.clear();
    notifyListeners();
  }

  Future<void> updateProduto(Produto produto) async {
    await storage.updateProduto(produto);
    await load();
  }

  Future<void> deleteProduto(String id) async {
    await storage.deleteProduto(id);
    await load();
  }
}
