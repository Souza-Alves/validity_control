import 'package:flutter/material.dart';
import '../models/local.dart';
import '../controllers/locais_controller.dart';
import '../theme/app_colors.dart';

class LocaisScreen extends StatefulWidget {
  const LocaisScreen({super.key});

  @override
  State<LocaisScreen> createState() => _LocaisScreenState();
}

class _LocaisScreenState extends State<LocaisScreen>
    with AutomaticKeepAliveClientMixin {
  late final LocaisController _c;
  final _nomeController = TextEditingController();
  bool _ativo = true;
  String? _editingId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = LocaisController()..addListener(_onControllerChanged);
    _c.load();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    await _c.load();
  }

  Future<void> _handleSave() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe o nome do local.')));
      return;
    }
    await _c.save(
      id: _editingId,
      nome: _nomeController.text.trim(),
      ativo: _ativo,
    );
    _nomeController.clear();
    setState(() {
      _ativo = true;
      _editingId = null;
    });
  }

  void _handleEdit(Local local) {
    _nomeController.text = local.nome;
    setState(() {
      _ativo = local.ativo;
      _editingId = local.id;
    });
  }

  void _handleDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Deseja excluir este local?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await _c.delete(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Form
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingId != null ? 'Editar Local' : 'Novo Local',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Local',
                  style: TextStyle(fontSize: 14, color: AppColors.textHeading),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Nome do local',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 14)),
                    Row(
                      children: [
                        Text(
                          _ativo ? 'Ativo' : 'Inativo',
                          style: TextStyle(
                            color: _ativo ? AppColors.primary : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _ativo,
                          onChanged: (v) => setState(() => _ativo = v),
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _handleSave,
                        child: Text(
                          _editingId != null ? 'Atualizar' : 'Salvar',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (_editingId != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neutralButton,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _nomeController.clear();
                            setState(() {
                              _ativo = true;
                              _editingId = null;
                            });
                          },
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _c.locais.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum local cadastrado',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _c.locais.length,
                    itemBuilder: (_, i) {
                      final item = _c.locais[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nome,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.ativo ? 'Ativo' : 'Inativo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: item.ativo
                                            ? AppColors.primary
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _handleEdit(item),
                                child: const Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _handleDelete(item.id),
                                child: const Text(
                                  'Excluir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _nomeController.dispose();
    super.dispose();
  }
}
