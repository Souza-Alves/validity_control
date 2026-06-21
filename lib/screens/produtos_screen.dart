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
import '../utils/email_report.dart';
import '../theme/app_colors.dart';
import '../controllers/produtos_controller.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/table_header_cell.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => ProdutosScreenState();
}

class ProdutosScreenState extends State<ProdutosScreen>
    with AutomaticKeepAliveClientMixin {
  late final ProdutosController _c;
  final _dataInicialCtrl = TextEditingController();
  final _dataFinalCtrl = TextEditingController();
  final GlobalKey _captureKey = GlobalKey();
  static const _cameraSaverChannel = MethodChannel('camera_image_saver');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _c = ProdutosController()..addListener(_onControllerChanged);
    _c.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.load();
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

  Future<void> _enviarEmail() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final itens = _c.proximosVencimentos(4);

    if (itens.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum produto com vencimento nos proximos 4 dias.'),
          ),
        );
      }
      return;
    }

    final report = buildEmailReport(
      titulo: 'Produtos proximos ao vencimento',
      data: todayStart,
      itens: itens,
    );
    final body = report.html;
    final plainTextBody = report.plain;
    final subject =
        'Controle de Validades - Produtos proximos ao vencimento (${du.formatDate(todayStart)})';

    // Android: abre um seletor (chooser) de apps de e-mail. O corpo visivel usa
    // o HTML "rich" (negrito + quebras), que o Gmail renderiza.
    if (Platform.isAndroid) {
      try {
        final ok = await const MethodChannel('email_sender').invokeMethod<bool>(
          'sendEmail',
          {'subject': subject, 'htmlBody': body, 'richBody': report.rich},
        );
        if (ok == true) return;
      } catch (_) {}
    }

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
    super.build(context);
    final sorted = _c.sorted;
    final localLabel = _c.filtrosLocal.isEmpty
        ? 'Todos'
        : _c.filtrosLocal.length <= 2
        ? _c.filtrosLocal.join(', ')
        : '${_c.filtrosLocal.length} selecionados';

    return SafeArea(
      child: GestureDetector(
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
                              'Dias:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 34,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: '4',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                                onChanged: (v) => _c.setDias(v),
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
                              'Data Inicial:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 34,
                              child: TextField(
                                controller: _dataInicialCtrl,
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
                                    _dataInicialCtrl.text = masked;
                                    _dataInicialCtrl.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: masked.length),
                                        );
                                  }
                                  _c.setDataInicial(masked);
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
                              'Data Final:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 34,
                              child: TextField(
                                controller: _dataFinalCtrl,
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
                                    _dataFinalCtrl.text = masked;
                                    _dataFinalCtrl.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: masked.length),
                                        );
                                  }
                                  _c.setDataFinal(masked);
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
            // Table
            Expanded(
              child: RepaintBoundary(
                key: _captureKey,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                              3,
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
                              4,
                              () => _c.toggleSort('produto'),
                            ),
                            _headerCell(
                              'Data${_c.sortArrow('validade')}',
                              2,
                              () => _c.toggleSort('validade'),
                              align: TextAlign.right,
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
                                            flex: 3,
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
                                            flex: 4,
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
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                            'Total: ${sorted.fold<int>(0, (s, p) => s + p.quantidade)} produto(s)',
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
            // Action buttons
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
                    onPressed: _enviarEmail,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Filtrar por local',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _dataInicialCtrl.dispose();
    _dataFinalCtrl.dispose();
    super.dispose();
  }
}
