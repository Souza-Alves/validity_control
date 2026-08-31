import 'package:flutter/foundation.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart' as storage;
import '../utils/date_utils.dart' as du;

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

/// Período (mês/ano) usado para filtrar o relatório pela validade dos produtos.
class Periodo {
  final int ano;
  final int mes; // 1-12
  const Periodo(this.ano, this.mes);

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.ano == ano && other.mes == mes;

  @override
  int get hashCode => Object.hash(ano, mes);

  static const _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  String get nomeMes => _nomesMeses[mes - 1];
  String get label => '$nomeMes/$ano';
}

/// Controller da tela de Relatorio: agrega os produtos por local.
class RelatorioController extends ChangeNotifier {
  List<LocalResumo> resumos = [];

  // Todos os produtos carregados; `produtos` expõe apenas o período selecionado.
  List<Produto> _allProdutos = [];
  Periodo? _periodo;
  bool loading = true;

  Periodo? get periodo => _periodo;

  /// Produtos filtrados pelo período (mês/ano) selecionado. Se não houver
  /// período, retorna todos.
  List<Produto> get produtos {
    if (_periodo == null) return _allProdutos;
    return _allProdutos.where((p) => _noPeriodo(p, _periodo!)).toList();
  }

  static bool _noPeriodo(Produto p, Periodo periodo) {
    final d = du.parseDate(p.validade);
    if (d == null) return false;
    return d.year == periodo.ano && d.month == periodo.mes;
  }

  /// Períodos (mês/ano) disponíveis nos dados, mais recentes primeiro.
  List<Periodo> get periodosDisponiveis {
    final set = <Periodo>{};
    for (final p in _allProdutos) {
      final d = du.parseDate(p.validade);
      if (d != null) set.add(Periodo(d.year, d.month));
    }
    final lista = set.toList()
      ..sort((a, b) {
        final y = b.ano.compareTo(a.ano);
        return y != 0 ? y : b.mes.compareTo(a.mes);
      });
    return lista;
  }

  /// Altera o período exibido e recomputa os resumos.
  void setPeriodo(Periodo? periodo) {
    _periodo = periodo;
    _recompute();
    notifyListeners();
  }

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

  List<Local> _locais = [];

  Future<void> load() async {
    if (resumos.isEmpty) {
      loading = true;
      notifyListeners();
    }

    _allProdutos = await storage.getProdutos();
    _locais = await storage.getLocais();

    // Se o período atual não existe mais nos dados, cai no mais recente.
    final disponiveis = periodosDisponiveis;
    if (_periodo == null || !disponiveis.contains(_periodo)) {
      _periodo = disponiveis.isNotEmpty ? disponiveis.first : null;
    }

    _recompute();
    loading = false;
    notifyListeners();
  }

  void _recompute() {
    final mapa = <String, _Agg>{};
    for (final p in produtos) {
      final agg = mapa.putIfAbsent(p.localNome, () => _Agg());
      agg.totalGeral += p.quantidade;
      if (p.situacao == 'Vendido') agg.vendidos += p.quantidade;
      if (p.status == 'Pendente') agg.pendentes += p.quantidade;
      if (p.status == 'Baixado') agg.baixados += p.quantidade;
    }

    // Ordena seguindo a ordem dos locais cadastrados; o que sobrar vai depois.
    final ordenados = <LocalResumo>[];
    final usados = <String>{};
    for (final l in _locais) {
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
  }

  // ============ Relatório comparativo ============

  /// Qtd de vencidos (Pendente/Baixado) de um local em um período específico.
  int vencidosNoPeriodo(String localNome, Periodo periodo) {
    return _allProdutos
        .where(
          (p) =>
              p.localNome == localNome &&
              _isVencido(p) &&
              _noPeriodo(p, periodo),
        )
        .fold(0, (s, p) => s + p.quantidade);
  }

  /// Qtd de vendidos de um local em um período específico.
  int vendidosNoPeriodo(String localNome, Periodo periodo) {
    return _allProdutos
        .where(
          (p) =>
              p.localNome == localNome &&
              p.situacao == 'Vendido' &&
              _noPeriodo(p, periodo),
        )
        .fold(0, (s, p) => s + p.quantidade);
  }

  /// Qtd total de produtos cadastrados de um local em um período específico.
  int totalNoPeriodo(String localNome, Periodo periodo) {
    return _allProdutos
        .where(
          (p) =>
              p.localNome == localNome && _noPeriodo(p, periodo),
        )
        .fold(0, (s, p) => s + p.quantidade);
  }

  /// Locais (nomes) que têm ao menos um produto em qualquer período, ordenados
  /// seguindo o cadastro de locais.
  List<String> get nomesLocais {
    final comProdutos = _allProdutos.map((p) => p.localNome).toSet();
    final ordenados = <String>[];
    for (final l in _locais) {
      if (comProdutos.contains(l.nome)) ordenados.add(l.nome);
    }
    final restantes = comProdutos.where((n) => !ordenados.contains(n)).toList()
      ..sort();
    return [...ordenados, ...restantes];
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
