import '../models/produto.dart';
import '../utils/date_utils.dart' as du;
import 'base_produto_controller.dart';

/// Controller da tela de Exportar.
///
/// Diferente da tela de Produtos, esta lista sempre exibe tudo (inclusive
/// produtos Vendidos e Vencidos), aplicando apenas os filtros escolhidos pelo
/// usuário (condição, status e período).
class ExportarController extends BaseProdutoController {
  String filtroCondicao = '';
  String filtroStatus = '';
  String periodoInicio = '';
  String periodoFim = '';

  @override
  List<Produto> get filtered {
    return produtos.where((p) {
      if (!isLocalAtivo(p)) return false;
      if (!matchesLocalFilter(p)) return false;
      if (filtroCondicao.isNotEmpty && p.situacao != filtroCondicao) {
        return false;
      }
      if (filtroCondicao == 'Vencido' &&
          filtroStatus.isNotEmpty &&
          p.status != filtroStatus) {
        return false;
      }
      if (periodoInicio.isNotEmpty && periodoFim.isNotEmpty) {
        final d = du.parseDate(p.validade);
        final start = du.parseDate(periodoInicio);
        final end = du.parseDate(periodoFim);
        if (d != null && start != null && end != null) {
          if (d.isBefore(start) || d.isAfter(end)) return false;
        }
      }
      return true;
    }).toList();
  }

  void setFiltroCondicao(String value) {
    filtroCondicao = value;
    if (filtroCondicao != 'Vencido') filtroStatus = '';
    notifyListeners();
  }

  void setFiltroStatus(String value) {
    filtroStatus = value;
    notifyListeners();
  }

  void setPeriodoInicio(String value) {
    periodoInicio = value;
    notifyListeners();
  }

  void setPeriodoFim(String value) {
    periodoFim = value;
    notifyListeners();
  }
}
