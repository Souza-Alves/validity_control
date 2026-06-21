import 'package:flutter/foundation.dart';
import '../models/produto.dart';
import '../storage/storage.dart' as storage;

/// Categorias de contagem exibidas no relatorio.
enum RelatorioCategoria { total, vendidos, pendentes, baixados, vencidos }

/// Resumo agregado dos produtos de um local para a tela de Relatorio.
class LocalResumo {
  final String nome;
  final int totalGeral;
  final int vendidos;
  final int pendentes;
  final int baixados;

  const LocalResumo({
    required this.nome,
    required this.totalGeral,
    required this.vendidos,
    required this.pendentes,
    required this.baixados,
  });
}

/// Controller da tela de Relatorio: agrega os produtos por local.
class RelatorioController extends ChangeNotifier {
  List<LocalResumo> resumos = [];
  List<Produto> produtos = [];
  bool loading = true;

  /// Lista os produtos de um local que pertencem a uma categoria do relatorio.
  List<Produto> itens(String localNome, RelatorioCategoria categoria) {
    return produtos.where((p) {
      if (p.localNome != localNome) return false;
      switch (categoria) {
        case RelatorioCategoria.total:
          return true;
        case RelatorioCategoria.vendidos:
          return p.situacao == 'Vendido';
        case RelatorioCategoria.pendentes:
          return p.status == 'Pendente';
        case RelatorioCategoria.baixados:
          return p.status == 'Baixado';
        case RelatorioCategoria.vencidos:
          return p.status == 'Pendente' || p.status == 'Baixado';
      }
    }).toList();
  }

  /// Lista os produtos de uma categoria somando todos os locais.
  List<Produto> itensGlobal(RelatorioCategoria categoria) {
    return produtos.where((p) {
      switch (categoria) {
        case RelatorioCategoria.total:
          return true;
        case RelatorioCategoria.vendidos:
          return p.situacao == 'Vendido';
        case RelatorioCategoria.pendentes:
          return p.status == 'Pendente';
        case RelatorioCategoria.baixados:
          return p.status == 'Baixado';
        case RelatorioCategoria.vencidos:
          return p.status == 'Pendente' || p.status == 'Baixado';
      }
    }).toList();
  }

  static bool _isVencido(Produto p) =>
      p.status == 'Pendente' || p.status == 'Baixado';

  static int _porQuantidade(Produto a, Produto b) {
    final q = b.quantidade.compareTo(a.quantidade);
    if (q != 0) return q;
    final n = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    if (n != 0) return n;
    return a.localNome.toLowerCase().compareTo(b.localNome.toLowerCase());
  }

  /// Top N produtos vencidos de um local, ordenados por quantidade.
  List<Produto> topVencidosLocal(String localNome, {int limit = 5}) {
    final lista =
        produtos
            .where((p) => p.localNome == localNome && _isVencido(p))
            .toList()
          ..sort(_porQuantidade);
    return lista.take(limit).toList();
  }

  /// Top N produtos vencidos de todos os locais, ordenados por quantidade.
  List<Produto> topVencidosGlobal({int limit = 10}) {
    final lista = produtos.where(_isVencido).toList()..sort(_porQuantidade);
    return lista.take(limit).toList();
  }

  int get geralTotal => resumos.fold(0, (s, r) => s + r.totalGeral);
  int get geralVendidos => resumos.fold(0, (s, r) => s + r.vendidos);
  int get geralPendentes => resumos.fold(0, (s, r) => s + r.pendentes);
  int get geralBaixados => resumos.fold(0, (s, r) => s + r.baixados);
  int get geralVencidos =>
      resumos.fold(0, (s, r) => s + r.pendentes + r.baixados);

  RelatorioController() {
    storage.dataChanged.addListener(_onDataChanged);
  }

  void _onDataChanged() => load();

  @override
  void dispose() {
    storage.dataChanged.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> load() async {
    if (resumos.isEmpty) {
      loading = true;
      notifyListeners();
    }

    final prods = await storage.getProdutos();
    final locais = await storage.getLocais();
    produtos = prods;

    final mapa = <String, _Agg>{};
    for (final p in prods) {
      final agg = mapa.putIfAbsent(p.localNome, () => _Agg());
      agg.totalGeral += p.quantidade;
      if (p.situacao == 'Vendido') agg.vendidos += p.quantidade;
      if (p.status == 'Pendente') agg.pendentes += p.quantidade;
      if (p.status == 'Baixado') agg.baixados += p.quantidade;
    }

    // Ordena seguindo a ordem dos locais cadastrados; o que sobrar vai depois.
    final ordenados = <LocalResumo>[];
    final usados = <String>{};
    for (final l in locais) {
      final agg = mapa[l.nome];
      if (agg != null) {
        ordenados.add(agg.toResumo(l.nome));
        usados.add(l.nome);
      }
    }
    final restantes = mapa.keys.where((n) => !usados.contains(n)).toList()
      ..sort();
    for (final n in restantes) {
      ordenados.add(mapa[n]!.toResumo(n));
    }

    resumos = ordenados;
    loading = false;
    notifyListeners();
  }
}

class _Agg {
  int totalGeral = 0;
  int vendidos = 0;
  int pendentes = 0;
  int baixados = 0;

  LocalResumo toResumo(String nome) => LocalResumo(
    nome: nome,
    totalGeral: totalGeral,
    vendidos: vendidos,
    pendentes: pendentes,
    baixados: baixados,
  );
}
