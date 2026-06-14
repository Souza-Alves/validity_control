import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xl;
import 'package:uuid/uuid.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart';
import '../main.dart' show kPrimaryColor;

class _ImportRow {
  final String predio;
  final int quantidade;
  final String produto;
  final String vencimento;
  _ImportRow({required this.predio, required this.quantidade, required this.produto, required this.vencimento});
}

class ImportarScreen extends StatefulWidget {
  const ImportarScreen({super.key});

  @override
  State<ImportarScreen> createState() => _ImportarScreenState();
}

class _ImportarScreenState extends State<ImportarScreen>
    with AutomaticKeepAliveClientMixin {
  List<_ImportRow> _importedRows = [];
  bool _imported = false;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _handlePickFile() async {
     // 1. Define o grupo de arquivos permitidos (Excel)
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'Planilhas Excel',
      extensions: <String>['xlsx', 'xls'],
    );

    // 2. Abre o seletor nativo do sistema
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    
    // Se o usuário cancelou a seleção, interrompe a execução
    if (file == null) return;

    // 3. Lê os bytes do arquivo selecionado de forma assíncrona
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao ler o arquivo.')),
        );
      }
      return;
    }

    // 4. Envia os bytes para a sua função de processamento existente
    _parseExcel(bytes);
  }

  void _parseExcel(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma planilha encontrada no arquivo.')));
      return;
    }
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return;

    final header = sheet.rows.first.map((c) => (c?.value?.toString() ?? '').toLowerCase().trim()).toList();
    final predioIdx = header.indexOf('predio');
    final qtdIdx = header.indexOf('quantidade');
    final prodIdx = header.indexOf('produto');
    final vencIdx = header.indexOf('vencimento');

    if (predioIdx < 0 || qtdIdx < 0 || prodIdx < 0 || vencIdx < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Colunas obrigatorias nao encontradas.')));
      return;
    }

    final rows = <_ImportRow>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final predio = row.length > predioIdx ? (row[predioIdx]?.value?.toString() ?? '') : '';
      final qtd = row.length > qtdIdx ? (int.tryParse(row[qtdIdx]?.value?.toString() ?? '') ?? 0) : 0;
      final prod = row.length > prodIdx ? (row[prodIdx]?.value?.toString() ?? '') : '';
      final venc = row.length > vencIdx ? (row[vencIdx]?.value?.toString() ?? '') : '';
      if (predio.isNotEmpty && prod.isNotEmpty) {
        rows.add(_ImportRow(predio: predio, quantidade: qtd, produto: prod, vencimento: venc));
      }
    }

    setState(() { _importedRows = rows; _imported = false; });
  }

  Future<void> _handleImport() async {
    if (_importedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para importar.')));
      return;
    }

    setState(() => _loading = true);

    final existingLocais = await getLocais();
    final localMap = <String, Local>{for (final l in existingLocais) l.nome.toLowerCase(): l};
    final newProdutos = <Produto>[];

    for (final row in _importedRows) {
      var local = localMap[row.predio.toLowerCase()];
      if (local == null) {
        local = Local(id: const Uuid().v4(), nome: row.predio, ativo: true);
        await addLocal(local);
        localMap[row.predio.toLowerCase()] = local;
      }
      newProdutos.add(Produto(
        id: const Uuid().v4(),
        localId: local.id,
        localNome: local.nome,
        quantidade: row.quantidade,
        nome: row.produto,
        validade: row.vencimento,
      ));
    }

    await addProdutos(newProdutos);
    setState(() { _imported = true; _loading = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${newProdutos.length} produto(s) importado(s) com sucesso!')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Importar Planilha Excel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const SizedBox(height: 8),
              const Text('O arquivo deve conter as colunas: predio, quantidade, produto e vencimento',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
                  onPressed: _loading ? null : _handlePickFile,
                  child: Text(_loading ? 'Processando...' : 'Selecionar Arquivo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
        if (_importedRows.isNotEmpty) ...[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pre-visualizacao (${_importedRows.length} itens)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (!_imported)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                    onPressed: _loading ? null : _handleImport,
                    child: Text(_loading ? 'Importando...' : 'Confirmar Importacao', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                if (_imported)
                  Row(
                    children: [
                      const Text('Importado com sucesso!', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                        onPressed: () => setState(() { _importedRows = []; _imported = false; }),
                        child: const Text('Nova Importacao', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimaryColor),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: kPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: const Row(
                      children: [
                        SizedBox(width: 30, child: Text('#', style: TextStyle(color: Colors.white, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Predio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 1, child: Text('Qtd', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Produto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Vencimento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _importedRows.length,
                      itemBuilder: (_, i) {
                        final row = _importedRows[i];
                        return Container(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 30, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))),
                              Expanded(flex: 2, child: Text(row.predio, style: const TextStyle(fontSize: 13))),
                              Expanded(flex: 1, child: Text('${row.quantidade}', style: const TextStyle(fontSize: 13))),
                              Expanded(flex: 2, child: Text(row.produto, style: const TextStyle(fontSize: 13))),
                              Expanded(flex: 2, child: Text(row.vencimento, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
