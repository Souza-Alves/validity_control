import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart' as storage;
import '../utils/id.dart';

String _normalizeYear(String yearStr) {
  if (yearStr.length <= 2) {
    final y = int.tryParse(yearStr) ?? 0;
    return (y <= 30 ? 2000 + y : 1900 + y).toString();
  }
  return yearStr;
}

String _pad2(int v) => v.toString().padLeft(2, '0');

/// Converte o valor da celula de vencimento para DD/MM/AAAA, aceitando data
/// nativa do Excel, numero serial (dias desde 1899-12-30) ou string.
String parseExcelDate(Object? cell) {
  if (cell == null) return '';
  if (cell is xl.DateCellValue) {
    return '${_pad2(cell.day)}/${_pad2(cell.month)}/${cell.year}';
  }
  if (cell is xl.DateTimeCellValue) {
    return '${_pad2(cell.day)}/${_pad2(cell.month)}/${cell.year}';
  }
  if (cell is xl.IntCellValue) {
    final d = DateTime(1899, 12, 30).add(Duration(days: cell.value));
    return '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';
  }
  if (cell is xl.DoubleCellValue) {
    final d = DateTime(1899, 12, 30).add(Duration(days: cell.value.round()));
    return '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';
  }
  final raw = cell is xl.TextCellValue
      ? cell.value.toString()
      : cell.toString();
  final s = raw.trim();
  if (s.isEmpty) return '';
  final serial = num.tryParse(s);
  if (serial != null) {
    final d = DateTime(1899, 12, 30).add(Duration(days: serial.round()));
    return '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';
  }
  if (s.contains('/')) {
    final parts = s.split('/');
    if (parts.length == 3) {
      return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${_normalizeYear(parts[2])}';
    }
  }
  if (s.contains('-')) {
    final parts = s.split('-');
    if (parts.length == 3) {
      // ISO YYYY-MM-DD
      return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${_normalizeYear(parts[0])}';
    }
  }
  return s;
}

class ImportRow {
  final String predio;
  final int quantidade;
  final String produto;
  final String vencimento;
  ImportRow({
    required this.predio,
    required this.quantidade,
    required this.produto,
    required this.vencimento,
  });
}

/// Controller da tela de Importação: faz o parse da planilha e grava em lote.
class ImportarController extends ChangeNotifier {
  List<ImportRow> rows = [];
  bool imported = false;
  bool loading = false;

  /// Faz o parse dos bytes do Excel. Retorna `null` em sucesso ou a mensagem
  /// de erro a ser exibida pela View.
  String? parse(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return 'Nenhuma planilha encontrada no arquivo.';
    }
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return null;

    final header = sheet.rows.first
        .map((c) => (c?.value?.toString() ?? '').toLowerCase().trim())
        .toList();
    final predioIdx = header.indexOf('predio');
    final qtdIdx = header.indexOf('quantidade');
    final prodIdx = header.indexOf('produto');
    final vencIdx = header.indexOf('vencimento');

    if (predioIdx < 0 || qtdIdx < 0 || prodIdx < 0 || vencIdx < 0) {
      return 'Colunas obrigatorias nao encontradas.';
    }

    final parsed = <ImportRow>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final predio = row.length > predioIdx
          ? (row[predioIdx]?.value?.toString() ?? '')
          : '';
      final qtd = row.length > qtdIdx
          ? (int.tryParse(row[qtdIdx]?.value?.toString() ?? '') ?? 0)
          : 0;
      final prod = row.length > prodIdx
          ? (row[prodIdx]?.value?.toString() ?? '')
          : '';
      final venc = row.length > vencIdx
          ? parseExcelDate(row[vencIdx]?.value)
          : '';
      if (predio.isNotEmpty && prod.isNotEmpty) {
        parsed.add(
          ImportRow(
            predio: predio,
            quantidade: qtd,
            produto: prod,
            vencimento: venc,
          ),
        );
      }
    }

    rows = parsed;
    imported = false;
    notifyListeners();
    return null;
  }

  /// Grava os itens importados em lote. Retorna a quantidade de produtos
  /// importados, ou `-1` se não houver dados.
  Future<int> import() async {
    if (rows.isEmpty) return -1;

    loading = true;
    notifyListeners();

    final existingLocais = await storage.getLocais();
    final localMap = <String, Local>{
      for (final l in existingLocais) l.nome.toLowerCase(): l,
    };
    final newLocais = <Local>[];
    final newProdutos = <Produto>[];

    for (final row in rows) {
      var local = localMap[row.predio.toLowerCase()];
      if (local == null) {
        local = Local(id: generateId(), nome: row.predio, ativo: true);
        newLocais.add(local);
        localMap[row.predio.toLowerCase()] = local;
      }
      newProdutos.add(
        Produto(
          id: generateId(),
          localId: local.id,
          localNome: local.nome,
          quantidade: row.quantidade,
          nome: row.produto,
          validade: row.vencimento,
        ),
      );
    }

    await storage.importBatch(newLocais, newProdutos);
    imported = true;
    loading = false;
    notifyListeners();
    return newProdutos.length;
  }

  void reset() {
    rows = [];
    imported = false;
    notifyListeners();
  }
}
