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
import '../models/local.dart';
import '../storage/storage.dart';
import '../utils/date_utils.dart' as du;
import '../main.dart' show kPrimaryColor;

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});

  @override
  State<ProdutosScreen> createState() => ProdutosScreenState();
}

class ProdutosScreenState extends State<ProdutosScreen>
    with AutomaticKeepAliveClientMixin {
  List<Produto> _produtos = [];
  List<Local> _locais = [];
  final List<String> _filtrosLocal = [];
  String _dataInicial = '';
  String _dataFinal = '';
  String _diasFiltro = '';
  String _sortField = 'validade';
  bool _sortAsc = true;
  bool _loading = true;
  final _dataInicialCtrl = TextEditingController();
  final _dataFinalCtrl = TextEditingController();
  final GlobalKey _captureKey = GlobalKey();
  static const _cameraSaverChannel = MethodChannel('camera_image_saver');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_handleDataChanged);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  void _handleDataChanged() {
    if (mounted) refresh();
  }

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    if (mounted && _produtos.isEmpty) setState(() => _loading = true);
    final prods = await getProdutos();
    final locs = await getLocais();
    if (mounted) {
      setState(() {
        _produtos = prods;
        _locais = locs;
        _loading = false;
      });
    }
  }

  bool _isLocalAtivo(Produto p) {
    for (final l in _locais) {
      if (l.id == p.localId) return l.ativo;
    }
    for (final l in _locais) {
      if (l.nome.toLowerCase() == p.localNome.toLowerCase()) return l.ativo;
    }
    return false;
  }

  List<Produto> get _filtered {
    return _produtos.where((p) {
      if (!_isLocalAtivo(p)) return false;
      if (p.situacao == 'Vendido' || p.situacao == 'Vencido') return false;
      if (_filtrosLocal.isNotEmpty) {
        if (!_filtrosLocal.any(
          (f) => p.localNome.toLowerCase() == f.toLowerCase(),
        )) {
          return false;
        }
      }
      if (_dataInicial.isNotEmpty && _dataFinal.isNotEmpty) {
        return du.isInRange(p.validade, _dataInicial, _dataFinal);
      }
      final days = int.tryParse(_diasFiltro);
      if (days != null && days >= 0) {
        return du.isWithinDays(p.validade, days);
      }
      return true;
    }).toList();
  }

  List<Produto> get _sorted {
    final list = List<Produto>.from(_filtered);
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'local':
          cmp = a.localNome.compareTo(b.localNome);
        case 'qtd':
          cmp = a.quantidade.compareTo(b.quantidade);
        case 'produto':
          cmp = a.nome.compareTo(b.nome);
        default:
          cmp = du.compareDates(a.validade, b.validade);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
    });
  }

  String _sortArrow(String field) =>
      _sortField == field ? (_sortAsc ? ' ▲' : ' ▼') : '';

  void _toggleLocalFilter(String nome) {
    setState(() {
      if (_filtrosLocal.contains(nome)) {
        _filtrosLocal.remove(nome);
      } else {
        _filtrosLocal.add(nome);
      }
    });
  }

  Future<void> _openEditModal(Produto produto) async {
    final locaisAtivos = _locais.where((l) => l.ativo).toList();
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
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
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
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
                        ? const Color(0xFF666666)
                        : const Color(0xFFBBBBBB),
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
                        backgroundColor: kPrimaryColor,
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
                        await updateProduto(
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
                        _loadData();
                      },
                      child: const FittedBox(child: Text('Salvar')),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFFE74C3C),
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
                                  await deleteProduto(produto.id);
                                  if (c.mounted) Navigator.pop(c);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadData();
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
                    backgroundColor: kPrimaryColor,
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
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final futureDate = todayStart.add(const Duration(days: 4));

    final itens = _produtos.where((p) {
      final d = du.parseDate(p.validade);
      return d != null && !d.isBefore(todayStart) && !d.isAfter(futureDate);
    }).toList()..sort((a, b) => a.localNome.compareTo(b.localNome));

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

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;color:#222;">');
    buffer.writeln('<div style="padding:16px;">');
    buffer.writeln('<p style="margin:0 0 8px 0;font-size:16px;font-weight:bold;">Produtos proximos ao vencimento</p>');
    buffer.writeln('<p style="margin:0 0 12px 0;font-size:12px;color:#555;">Gerado em ${du.formatDate(todayStart)}</p>');
    buffer.writeln('<table role="presentation" cellspacing="0" cellpadding="6" border="1" style="border-collapse:collapse;width:100%;font-size:12px;border-color:#cccccc;">');
    buffer.writeln('<tr style="background-color:#f4f4f4;">');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Local</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Qtd</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Produto</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Validade</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Situacao</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Status</th>');
    buffer.writeln('</tr>');
    for (final p in itens) {
      buffer.writeln('<tr>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.localNome)}</td>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${p.quantidade}</td>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.nome)}</td>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.validade)}</td>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.situacao.isEmpty ? '-' : p.situacao)}</td>');
      buffer.writeln('<td style="border:1px solid #cccccc;padding:8px;">${_escapeHtml(p.status.isEmpty ? '-' : p.status)}</td>');
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table>');
    buffer.writeln('<p style="margin:12px 0 0 0;font-size:12px;"><strong>Total:</strong> ${itens.length} produto(s)</p>');
    buffer.writeln('</div></body></html>');

    final body = buffer.toString();
    final plainTextBody = [
      'Controle de Validades',
      'Produtos proximos ao vencimento',
      'Gerado em ${du.formatDate(todayStart)}',
      '',
      'Local | Qtd | Produto | Validade | Situacao | Status',
      for (final p in itens)
        '${p.localNome} | ${p.quantidade} | ${p.nome} | ${p.validade} | ${p.situacao.isEmpty ? '-' : p.situacao} | ${p.status.isEmpty ? '-' : p.status}',
      '',
      'Total: ${itens.length} produto(s)',
    ].join('\n');
    final subject =
        'Controle de Validades - Produtos proximos ao vencimento (${du.formatDate(todayStart)})';

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
    final sorted = _sorted;
    final localLabel = _filtrosLocal.isEmpty
        ? 'Todos'
        : _filtrosLocal.length <= 2
        ? _filtrosLocal.join(', ')
        : '${_filtrosLocal.length} selecionados';

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
                                color: Color(0xFF666666),
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
                                  border: Border.all(
                                    color: const Color(0xFFCCCCCC),
                                  ),
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
                                color: Color(0xFF666666),
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
                                onChanged: (v) =>
                                    setState(() => _diasFiltro = v),
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
                                color: Color(0xFF666666),
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
                                  setState(() => _dataInicial = masked);
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
                                color: Color(0xFF666666),
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
                                  setState(() => _dataFinal = masked);
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
                    border: Border.all(color: kPrimaryColor),
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        color: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            _headerCell(
                              'Local${_sortArrow('local')}',
                              3,
                              () => _toggleSort('local'),
                            ),
                            _headerCell(
                              'Qtd${_sortArrow('qtd')}',
                              1,
                              () => _toggleSort('qtd'),
                              align: TextAlign.center,
                            ),
                            _headerCell(
                              'Produto${_sortArrow('produto')}',
                              4,
                              () => _toggleSort('produto'),
                            ),
                            _headerCell(
                              'Data${_sortArrow('validade')}',
                              2,
                              () => _toggleSort('validade'),
                              align: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: kPrimaryColor,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Carregando...',
                                      style: TextStyle(
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : sorted.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum produto encontrado',
                                  style: TextStyle(color: Color(0xFF999999)),
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
                                            color: Color(0xFFEEEEEE),
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
                      backgroundColor: kPrimaryColor,
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
                      backgroundColor: kPrimaryColor,
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
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            text,
            textAlign: align,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
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
                          value: _filtrosLocal.isEmpty,
                          onChanged: (_) {
                            setState(() => _filtrosLocal.clear());
                            setSheetState(() {});
                          },
                        ),
                        title: const Text('Todos'),
                        onTap: () {
                          setState(() => _filtrosLocal.clear());
                          setSheetState(() {});
                        },
                      ),
                      ..._locais.where((l) => l.ativo).map((l) {
                        final sel = _filtrosLocal.contains(l.nome);
                        return ListTile(
                          leading: Checkbox(
                            value: sel,
                            activeColor: kPrimaryColor,
                            onChanged: (_) {
                              _toggleLocalFilter(l.nome);
                              setSheetState(() {});
                            },
                          ),
                          title: Text(
                            l.nome,
                            style: sel
                                ? const TextStyle(
                                    color: Color(0xFF4A8A1A),
                                    fontWeight: FontWeight.bold,
                                  )
                                : null,
                          ),
                          onTap: () {
                            _toggleLocalFilter(l.nome);
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
    dataChanged.removeListener(_handleDataChanged);
    _dataInicialCtrl.dispose();
    _dataFinalCtrl.dispose();
    super.dispose();
  }
}
