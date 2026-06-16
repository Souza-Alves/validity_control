import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter/services.dart';
import 'package:open_filex_plus/open_filex_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/produto.dart';
import '../utils/date_utils.dart' as du;
import '../theme/app_colors.dart';
import '../controllers/exportar_controller.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/table_header_cell.dart';

class ExportarScreen extends StatefulWidget {
  const ExportarScreen({super.key});

  @override
  State<ExportarScreen> createState() => _ExportarScreenState();
}

class _ExportarScreenState extends State<ExportarScreen> {
  late final ExportarController _c;
  final _periodoInicioCtrl = TextEditingController();
  final _periodoFimCtrl = TextEditingController();
  final GlobalKey _captureKey = GlobalKey();
  static const _cameraSaverChannel = MethodChannel('camera_image_saver');

  @override
  void initState() {
    super.initState();
    _c = ExportarController()..addListener(_onControllerChanged);
    _c.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.load();
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _periodoInicioCtrl.dispose();
    _periodoFimCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    await _c.load();
  }

  Future<void> _openEditModal(Produto produto) async {
    final locaisAtivos = _c.locais.where((l) => l.ativo).toList();
    String editLocalId = produto.localId;
    String editLocalNome = produto.localNome;
    String editNome = produto.nome;
    String editValidade = produto.validade;
    String editQuantidade = produto.quantidade.toString();
    String editSituacao = produto.situacao;
    String editStatus = produto.status;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Produto', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Localizacao:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: locaisAtivos.any((l) => l.id == editLocalId)
                      ? editLocalId
                      : null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: locaisAtivos
                      .map(
                        (l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.nome)),
                      )
                      .toList(),
                  onChanged: (v) {
                    final loc = locaisAtivos.firstWhere((l) => l.id == v);
                    setDialogState(() {
                      editLocalId = loc.id;
                      editLocalNome = loc.nome;
                    });
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Produto:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editNome,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) => editNome = v,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Validade:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editValidade,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'DD/MM/AAAA',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  onChanged: (v) {
                    final masked = du.applyDateMask(v);
                    editValidade = masked;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quantidade:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: editQuantidade,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => editQuantidade = v,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Situacao:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: editSituacao.isEmpty ? null : editSituacao,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('Selecione'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Nenhum')),
                    DropdownMenuItem(value: 'Vendido', child: Text('Vendido')),
                    DropdownMenuItem(value: 'Vencido', child: Text('Vencido')),
                  ],
                  onChanged: (v) => setDialogState(() {
                    editSituacao = v ?? '';
                    if (editSituacao != 'Vencido') editStatus = '';
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Status:',
                  style: TextStyle(
                    fontSize: 13,
                    color: editSituacao == 'Vencido'
                        ? AppColors.textSecondary
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: editStatus.isEmpty ? null : editStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    enabled: editSituacao == 'Vencido',
                  ),
                  hint: Text(
                    editSituacao == 'Vencido'
                        ? 'Selecione'
                        : 'Disponivel apenas para Vencido',
                    overflow: TextOverflow.ellipsis,
                  ),
                  items: editSituacao == 'Vencido'
                      ? const [
                          DropdownMenuItem(value: '', child: Text('Nenhum')),
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
                  onChanged: editSituacao == 'Vencido'
                      ? (v) => setDialogState(() => editStatus = v ?? '')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (editNome.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Nome do produto e obrigatorio.'),
                            ),
                          );
                          return;
                        }
                        if (editValidade.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Data de validade e obrigatoria.'),
                            ),
                          );
                          return;
                        }
                        final qty = int.tryParse(editQuantidade);
                        if (qty == null || qty < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Quantidade invalida.'),
                            ),
                          );
                          return;
                        }
                        await _c.updateProduto(
                          produto.copyWith(
                            localId: editLocalId,
                            localNome: editLocalNome,
                            nome: editNome,
                            validade: editValidade,
                            quantidade: qty,
                            situacao: editSituacao,
                            status: editSituacao == 'Vencido' ? editStatus : '',
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const FittedBox(child: Text('Salvar')),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirmar remoção'),
                            content: Text(
                              'Deseja remover o produto "${produto.nome}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const FittedBox(child: Text('Cancelar')),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  await _c.deleteProduto(produto.id);
                                  if (c.mounted) Navigator.pop(c);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: const FittedBox(child: Text('Remover')),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const FittedBox(child: Text('Remover')),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const FittedBox(child: Text('Cancelar')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _salvarPrintTela() async {
    final contextBox = _captureKey.currentContext;
    final renderObject = contextBox?.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel capturar a lista.')),
        );
      }
      return;
    }

    try {
      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Sem dados da imagem');
      }

      final savedUri = await _cameraSaverChannel.invokeMethod<String>(
        'saveImageToCamera',
        {
          'imageBytes': byteData.buffer.asUint8List(),
          'quality': 100,
          'name': 'controle_validades_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      if (mounted) {
        if (savedUri != null && savedUri.isNotEmpty) {
          final filePath = savedUri;
          final shouldOpenGallery = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Imagem salva'),
              content: const Text('Deseja abrir a imagem salva na galeria?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Nao'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Sim'),
                ),
              ],
            ),
          );

          if (shouldOpenGallery == true && filePath.isNotEmpty) {
            try {
              final result = await OpenFilex.open(filePath);
              if (result.type == ResultType.done) {
                return;
              }
            } catch (_) {}

            if (Platform.isAndroid) {
              try {
                final uri =
                    filePath.startsWith('content://') ||
                        filePath.startsWith('file://')
                    ? Uri.parse(filePath)
                    : Uri.file(filePath);
                final intent = AndroidIntent(
                  action: 'android.intent.action.VIEW',
                  data: uri.toString(),
                  type: 'image/*',
                );
                await intent.launch();
                return;
              } catch (_) {}
            }

            try {
              final galleryUri = Uri.parse(
                'content://media/external/images/media',
              );
              if (await canLaunchUrl(galleryUri)) {
                await launchUrl(
                  galleryUri,
                  mode: LaunchMode.externalApplication,
                );
                return;
              }
            } catch (_) {}

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Imagem salva. Você pode encontrá-la na galeria.',
                  ),
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel salvar a imagem.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel salvar a imagem.')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final sorted = _c.sorted;
    if (sorted.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhum produto para enviar com os filtros aplicados.',
            ),
          ),
        );
      }
      return;
    }
    final today = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln(
      '<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;color:#222;">',
    );
    buffer.writeln('<div style="padding:16px;">');
    buffer.writeln(
      '<p style="margin:0 0 8px 0;font-size:16px;font-weight:bold;">Relatorio de Produtos - Controle de Validades</p>',
    );
    buffer.writeln(
      '<p style="margin:0 0 12px 0;font-size:12px;color:#555;">Gerado em ${du.formatDate(today)}</p>',
    );
    buffer.writeln(
      '<table role="presentation" cellspacing="0" cellpadding="6" border="1" style="border-collapse:collapse;width:100%;font-size:12px;border-color:#cccccc;">',
    );
    buffer.writeln('<tr style="background-color:#f4f4f4;">');
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Local</th>',
    );
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Qtd</th>',
    );
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Produto</th>',
    );
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Validade</th>',
    );
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Situacao</th>',
    );
    buffer.writeln(
      '<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Status</th>',
    );
    buffer.writeln('</tr>');
    for (final p in sorted) {
      buffer.writeln('<tr>');
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.localNome)}</td>',
      );
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${p.quantidade}</td>',
      );
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.nome)}</td>',
      );
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.validade)}</td>',
      );
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.situacao.isEmpty ? '-' : p.situacao)}</td>',
      );
      buffer.writeln(
        '<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.status.isEmpty ? '-' : p.status)}</td>',
      );
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table>');
    buffer.writeln(
      '<p style="margin:12px 0 0 0;font-size:12px;"><strong>Total:</strong> ${sorted.length} produto(s)</p>',
    );
    buffer.writeln('</div></body></html>');

    final body = buffer.toString();
    final plainTextBody = [
      'Controle de Validades',
      'Relatorio de Produtos',
      'Gerado em ${du.formatDate(today)}',
      '',
      'Local | Qtd | Produto | Validade | Situacao | Status',
      for (final p in sorted)
        '${p.localNome} | ${p.quantidade} | ${p.nome} | ${p.validade} | ${p.situacao.isEmpty ? '-' : p.situacao} | ${p.status.isEmpty ? '-' : p.status}',
      '',
      'Total: ${sorted.length} produto(s)',
    ].join('\n');
    final subject =
        'Controle de Validades - Relatorio (${du.formatDate(today)})';

    try {
      final capabilities = await FlutterEmailSender.getCapabilities();
      final useHtml = capabilities.supportsHtmlBody;
      final email = Email(
        subject: subject,
        body: useHtml ? body : plainTextBody,
        isHTML: useHtml,
        recipients: const [],
      );

      if (capabilities.canSend) {
        await FlutterEmailSender.send(email);
        return;
      }

      throw FlutterEmailSenderNotAvailableException(
        'No email client available',
      );
    } on FlutterEmailSenderNotAvailableException catch (_) {
      final fallbackBody = plainTextBody.trim();
      final mailtoUri = Uri(
        scheme: 'mailto',
        queryParameters: {'subject': subject, 'body': fallbackBody},
      );

      try {
        if (await canLaunchUrl(mailtoUri)) {
          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      if (Platform.isAndroid) {
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: mailtoUri.toString(),
          );
          await intent.launch();
          return;
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel abrir o app de email.'),
          ),
        );
      }
    } catch (_) {
      final fallbackBody = plainTextBody.trim();
      final mailtoUri = Uri(
        scheme: 'mailto',
        queryParameters: {'subject': subject, 'body': fallbackBody},
      );

      try {
        if (await canLaunchUrl(mailtoUri)) {
          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      if (Platform.isAndroid) {
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: mailtoUri.toString(),
          );
          await intent.launch();
          return;
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel abrir o app de email.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _c.sorted;
    final localLabel = _c.filtrosLocal.isEmpty
        ? 'Todos'
        : _c.filtrosLocal.length <= 2
        ? _c.filtrosLocal.join(', ')
        : '${_c.filtrosLocal.length} selecionados';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Local:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () => _showLocalFilterSheet(),
                            child: Container(
                              width: double.infinity,
                              height: 34,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                localLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Condicao:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _c.filtroCondicao.isEmpty
                                  ? null
                                  : _c.filtroCondicao,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                isDense: true,
                              ),
                              hint: const Text(
                                'Todos',
                                style: TextStyle(fontSize: 14),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: 'Vendido',
                                  child: Text('Vendido'),
                                ),
                                DropdownMenuItem(
                                  value: 'Vencido',
                                  child: Text('Vencido'),
                                ),
                              ],
                              onChanged: (v) => _c.setFiltroCondicao(v ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _c.filtroStatus.isEmpty
                                  ? null
                                  : _c.filtroStatus,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                isDense: true,
                                enabled: _c.filtroCondicao == 'Vencido',
                              ),
                              hint: Text(
                                _c.filtroCondicao == 'Vencido'
                                    ? 'Todos'
                                    : 'Apenas Vencido',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _c.filtroCondicao == 'Vencido'
                                      ? null
                                      : AppColors.textDisabled,
                                ),
                              ),
                              isExpanded: true,
                              items: _c.filtroCondicao == 'Vencido'
                                  ? const [
                                      DropdownMenuItem(
                                        value: '',
                                        child: Text('Todos'),
                                      ),
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
                              onChanged: _c.filtroCondicao == 'Vencido'
                                  ? (v) => _c.setFiltroStatus(v ?? '')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Periodo Inicio:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _periodoInicioCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'DD/MM/AAAA',
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _periodoInicioCtrl.text = masked;
                                  _periodoInicioCtrl.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(offset: masked.length),
                                      );
                                }
                                _c.setPeriodoInicio(masked);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Periodo Fim:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: TextField(
                              controller: _periodoFimCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'DD/MM/AAAA',
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onChanged: (v) {
                                final masked = du.applyDateMask(v);
                                if (masked != v) {
                                  _periodoFimCtrl.text = masked;
                                  _periodoFimCtrl.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(offset: masked.length),
                                      );
                                }
                                _c.setPeriodoFim(masked);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table with sticky header
          Expanded(
            child: RepaintBoundary(
              key: _captureKey,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          _headerCell(
                            'Local${_c.sortArrow('local')}',
                            2,
                            () => _c.toggleSort('local'),
                          ),
                          _headerCell(
                            'Qtd${_c.sortArrow('qtd')}',
                            1,
                            () => _c.toggleSort('qtd'),
                            align: TextAlign.center,
                          ),
                          _headerCell(
                            'Produto${_c.sortArrow('produto')}',
                            3,
                            () => _c.toggleSort('produto'),
                          ),
                          _headerCell(
                            'Data${_c.sortArrow('validade')}',
                            2,
                            () => _c.toggleSort('validade'),
                          ),
                          _headerCell(
                            'Situação${_c.sortArrow('situacao')}',
                            2,
                            () => _c.toggleSort('situacao'),
                          ),
                          _headerCell(
                            'Status${_c.sortArrow('status')}',
                            2,
                            () => _c.toggleSort('status'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _c.loading
                          ? const LoadingIndicator()
                          : sorted.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum produto encontrado',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: sorted.length,
                              itemBuilder: (_, i) {
                                final item = sorted[i];
                                return InkWell(
                                  onTap: () => _openEditModal(item),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.divider,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            item.localNome,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${item.quantidade}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            item.nome,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            du.formatShort(item.validade),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            item.situacao.isEmpty
                                                ? '-'
                                                : item.situacao,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            item.status.isEmpty
                                                ? '-'
                                                : item.status,
                                            style: const TextStyle(
                                              fontSize: 11,
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
                    if (!_c.loading)
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.primary),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Total: ${sorted.length} produto(s)',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Action buttons outside table
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 5),
            child: Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 40),
                  ),
                  onPressed: _salvarPrintTela,
                  child: const Text(
                    'Print de tela',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(170, 40),
                  ),
                  onPressed: _handleExport,
                  child: const Text(
                    'Enviar por Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String text,
    int flex,
    VoidCallback onTap, {
    TextAlign align = TextAlign.left,
  }) {
    return TableHeaderCell(text: text, flex: flex, onTap: onTap, align: align);
  }

  void _showLocalFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Checkbox(
                      value: _c.filtrosLocal.isEmpty,
                      onChanged: (_) {
                        _c.clearLocalFilters();
                        setSheetState(() {});
                      },
                    ),
                    title: const Text('Todos'),
                    onTap: () {
                      _c.clearLocalFilters();
                      setSheetState(() {});
                    },
                  ),
                  ..._c.locais.where((l) => l.ativo).map((l) {
                    final sel = _c.filtrosLocal.contains(l.nome);
                    return ListTile(
                      leading: Checkbox(
                        value: sel,
                        activeColor: AppColors.primary,
                        onChanged: (_) {
                          _c.toggleLocalFilter(l.nome);
                          setSheetState(() {});
                        },
                      ),
                      title: Text(
                        l.nome,
                        style: sel
                            ? const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                      onTap: () {
                        _c.toggleLocalFilter(l.nome);
                        setSheetState(() {});
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
