import '../models/produto.dart';
import '../utils/date_utils.dart' as du;
import 'base_produto_controller.dart';

/// Controller da tela de Produtos.
///
/// Oculta da lista os produtos com situação "Vendido" ou "Vencido" e aplica
/// os filtros por período (data inicial/final) e por dias até o vencimento.
class ProdutosController extends BaseProdutoController {
  String dataInicial = '';
  String dataFinal = '';
  String diasFiltro = '';

  @override
  List<Produto> get filtered {
    return produtos.where((p) {
      if (!isLocalAtivo(p)) return false;
      if (p.situacao == 'Vendido' || p.situacao == 'Vencido') return false;
      if (!matchesLocalFilter(p)) return false;
      if (dataInicial.isNotEmpty && dataFinal.isNotEmpty) {
        return du.isInRange(p.validade, dataInicial, dataFinal);
      }
      final days = int.tryParse(diasFiltro);
      if (days != null && days >= 0) {
        return du.isWithinDays(p.validade, days);
      }
      return true;
    }).toList();
  }

  void setDataInicial(String value) {
    dataInicial = value;
    notifyListeners();
  }

  void setDataFinal(String value) {
    dataFinal = value;
    notifyListeners();
  }

  void setDias(String value) {
    diasFiltro = value;
    notifyListeners();
  }

  /// Produtos que vencem nos próximos [dias] dias (usado no envio por e-mail).
  List<Produto> proximosVencimentos(int dias) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final limite = todayStart.add(Duration(days: dias));
    final itens = produtos.where((p) {
      final d = du.parseDate(p.validade);
      return d != null && !d.isBefore(todayStart) && !d.isAfter(limite);
    }).toList()..sort((a, b) => a.localNome.compareTo(b.localNome));
    return itens;
  }
}
