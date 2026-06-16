import 'package:flutter/material.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../storage/storage.dart';
import '../utils/date_utils.dart' as du;
import '../utils/id.dart';
import '../theme/app_colors.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => CadastroScreenState();
}

class CadastroScreenState extends State<CadastroScreen> {
  List<Local> _locais = [];
  String _localId = '';
  String _localNome = '';
  final _quantidadeCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _validadeCtrl = TextEditingController();
  String _situacao = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_handleDataChanged);
    _loadLocais();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLocais();
  }

  void _handleDataChanged() {
    if (mounted) refresh();
  }

  Future<void> refresh() async {
    await _loadLocais();
  }

  Future<void> _loadLocais() async {
    final locs = await getLocaisAtivos();
    if (mounted) setState(() => _locais = locs);
  }

  Future<void> _handleSave() async {
    if (_localId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione a localizacao.')));
      return;
    }
    if (_quantidadeCtrl.text.trim().isEmpty ||
        int.tryParse(_quantidadeCtrl.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a quantidade (numerico).')),
      );
      return;
    }
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do produto.')),
      );
      return;
    }
    if (_validadeCtrl.text.trim().isEmpty ||
        du.parseDate(_validadeCtrl.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a validade no formato DD/MM/AAAA.'),
        ),
      );
      return;
    }

    await addProduto(
      Produto(
        id: generateId(),
        localId: _localId,
        localNome: _localNome,
        quantidade: int.parse(_quantidadeCtrl.text),
        nome: _nomeCtrl.text.trim(),
        validade: _validadeCtrl.text,
        situacao: _situacao,
        status: _status,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto cadastrado com sucesso!')),
      );
    }
    _quantidadeCtrl.clear();
    _nomeCtrl.clear();
    _validadeCtrl.clear();
    setState(() {
      _localId = '';
      _localNome = '';
      _situacao = '';
      _status = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cadastro de Produto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Localizacao',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _localId.isEmpty ? null : _localId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                hint: const Text(
                  'Selecione o local...',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                items: _locais
                    .map(
                      (l) => DropdownMenuItem(value: l.id, child: Text(l.nome)),
                    )
                    .toList(),
                onChanged: (v) {
                  final loc = _locais.firstWhere((l) => l.id == v);
                  setState(() {
                    _localId = loc.id;
                    _localNome = loc.nome;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Quantidade',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _quantidadeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Quantidade',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Produto',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Nome do produto',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Validade',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _validadeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'DD/MM/AAAA',
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (v) {
                  final masked = du.applyDateMask(v);
                  if (masked != v) {
                    _validadeCtrl.value = TextEditingValue(
                      text: masked,
                      selection: TextSelection.collapsed(offset: masked.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Situacao',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _situacao.isEmpty ? null : _situacao,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                hint: const Text(
                  'Selecione...',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                items: const [
                  DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                  DropdownMenuItem(value: 'Vencido', child: Text('Vencido')),
                ],
                onChanged: (v) => setState(() {
                  _situacao = v ?? '';
                  if (_situacao != 'Vencido') _status = '';
                }),
              ),
              const SizedBox(height: 8),
              const Text(
                'Status',
                style: TextStyle(fontSize: 14, color: AppColors.textHeading),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _status.isEmpty ? null : _status,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  enabled: _situacao == 'Vencido',
                ),
                hint: Text(
                  _situacao == 'Vencido'
                      ? 'Selecione...'
                      : 'Disponivel apenas para Vencido',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                items: _situacao == 'Vencido'
                    ? const [
                        DropdownMenuItem(
                          value: 'Baixado',
                          child: Text('Baixado'),
                        ),
                        DropdownMenuItem(
                          value: 'Pendente',
                          child: Text('Pendente'),
                        ),
                      ]
                    : null,
                onChanged: _situacao == 'Vencido'
                    ? (v) => setState(() => _status = v ?? '')
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _handleSave,
                  child: const Text(
                    'Salvar Produto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    dataChanged.removeListener(_handleDataChanged);
    _quantidadeCtrl.dispose();
    _nomeCtrl.dispose();
    _validadeCtrl.dispose();
    super.dispose();
  }
}
