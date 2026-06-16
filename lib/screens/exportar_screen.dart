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

class ExportarScreen extends StatefulWidget {
  const ExportarScreen({super.key});

  @override
  State<ExportarScreen> createState() => _ExportarScreenState();
}

class _ExportarScreenState extends State<ExportarScreen> {
  List<Produto> _produtos = [];
  List<Local> _locais = [];
  final List<String> _filtrosLocal = [];
  String _filtroCondicao = '';
  String _filtroStatus = '';
  String _periodoInicio = '';
  String _periodoFim = '';
  String _sortField = 'validade';
  bool _sortAsc = true;
  bool _loading = true;
  final _periodoInicioCtrl = TextEditingController();
  final _periodoFimCtrl = TextEditingController();
  final GlobalKey _captureKey = GlobalKey();
  static const _cameraSaverChannel = MethodChannel('camera_image_saver');

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

  @override
  void dispose() {
    dataChanged.removeListener(_handleDataChanged);
    _periodoInicioCtrl.dispose();
    _periodoFimCtrl.dispose();
    super.dispose();
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
    if (mounted)
      setState(() {
        _produtos = prods;
        _locais = locs;
        _loading = false;
      });
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
      if (_filtrosLocal.isNotEmpty) {
        if (!_filtrosLocal.any(
          (f) => p.localNome.toLowerCase() == f.toLowerCase(),
        ))
          return false;
      }
      if (_filtroCondicao.isNotEmpty && p.situacao != _filtroCondicao)
        return false;
      if (_filtroCondicao == 'Vencido' &&
          _filtroStatus.isNotEmpty &&
          p.status != _filtroStatus)
        return false;
      if (_periodoInicio.isNotEmpty && _periodoFim.isNotEmpty) {
        final d = du.parseDate(p.validade);
        final start = du.parseDate(_periodoInicio);
        final end = du.parseDate(_periodoFim);
        if (d != null && start != null && end != null) {
          if (d.isBefore(start) || d.isAfter(end)) return false;
        }
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
        case 'situacao':
          cmp = a.situacao.compareTo(b.situacao);
        case 'status':
          cmp = a.status.compareTo(b.status);
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

          if (shouldOpenGallery == true &&
              filePath != null &&
              filePath.isNotEmpty) {
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
    final sorted = _sorted;
    if (sorted.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhum produto para enviar com os filtros aplicados.',
            ),
          ),
        );
      return;
    }
    final today = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;color:#222;">');
    buffer.writeln('<div style="padding:16px;">');
    buffer.writeln('<p style="margin:0 0 8px 0;font-size:16px;font-weight:bold;">Relatorio de Produtos - Controle de Validades</p>');
    buffer.writeln('<p style="margin:0 0 12px 0;font-size:12px;color:#555;">Gerado em ${du.formatDate(today)}</p>');
    buffer.writeln('<table role="presentation" cellspacing="0" cellpadding="6" border="1" style="border-collapse:collapse;width:100%;font-size:12px;border-color:#cccccc;">');
    buffer.writeln('<tr style="background-color:#f4f4f4;">');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Local</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Qtd</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Produto</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Validade</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Situacao</th>');
    buffer.writeln('<th style="border:1px solid #cccccc;padding:8px;text-align:left;">Status</th>');
    buffer.writeln('</tr>');
    for (final p in sorted) {
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
    buffer.writeln('<p style="margin:12px 0 0 0;font-size:12px;"><strong>Total:</strong> ${sorted.length} produto(s)</p>');
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
    final sorted = _sorted;
    final localLabel = _filtrosLocal.isEmpty
        ? 'Todos'
        : _filtrosLocal.length <= 2
        ? _filtrosLocal.join(', ')
        : '${_filtrosLocal.length} selecionados';

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
                            'Condicao:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filtroCondicao.isEmpty
                                  ? null
                                  : _filtroCondicao,
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
                              onChanged: (v) => setState(() {
                                _filtroCondicao = v ?? '';
                                if (_filtroCondicao != 'Vencido')
                                  _filtroStatus = '';
                              }),
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
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filtroStatus.isEmpty
                                  ? null
                                  : _filtroStatus,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                isDense: true,
                                enabled: _filtroCondicao == 'Vencido',
                              ),
                              hint: Text(
                                _filtroCondicao == 'Vencido'
                                    ? 'Todos'
                                    : 'Apenas Vencido',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filtroCondicao == 'Vencido'
                                      ? null
                                      : const Color(0xFFBBBBBB),
                                ),
                              ),
                              isExpanded: true,
                              items: _filtroCondicao == 'Vencido'
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
                              onChanged: _filtroCondicao == 'Vencido'
                                  ? (v) =>
                                        setState(() => _filtroStatus = v ?? '')
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
                              color: Color(0xFF666666),
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
                                setState(() => _periodoInicio = masked);
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
                              color: Color(0xFF666666),
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
                                setState(() => _periodoFim = masked);
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
                            2,
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
                            3,
                            () => _toggleSort('produto'),
                          ),
                          _headerCell(
                            'Data${_sortArrow('validade')}',
                            2,
                            () => _toggleSort('validade'),
                          ),
                          _headerCell(
                            'Situação${_sortArrow('situacao')}',
                            2,
                            () => _toggleSort('situacao'),
                          ),
                          _headerCell(
                            'Status${_sortArrow('status')}',
                            2,
                            () => _toggleSort('status'),
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
                                    style: TextStyle(color: Color(0xFF999999)),
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
                                return Container(
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
                                        flex: 2,
                                        child: Text(
                                          item.localNome,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${item.quantidade}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.nome,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          du.formatShort(item.validade),
                                          style: const TextStyle(fontSize: 11),
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
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.status.isEmpty
                                              ? '-'
                                              : item.status,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
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
          ),
          // Action buttons outside table
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
