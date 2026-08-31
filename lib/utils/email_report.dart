import '../models/produto.dart';
import 'date_utils.dart' as du;

/// Conteudo de um e-mail de relatorio em tres formatos:
/// - [html]: tabela HTML completa (para apps que suportam corpo HTML real).
/// - [rich]: HTML simples (negrito + quebras de linha) que o Gmail renderiza
///   na tela de redacao, ja que ele descarta tabelas.
/// - [plain]: texto puro de fallback.
class EmailReport {
  final String html;
  final String rich;
  final String plain;

  const EmailReport({
    required this.html,
    required this.rich,
    required this.plain,
  });
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _situacaoStatus(Produto p) {
  final partes = <String>[
    if (p.situacao.isNotEmpty) p.situacao,
    if (p.status.isNotEmpty) p.status,
  ];
  return partes.join(' · ');
}

/// Monta o conteudo do e-mail agrupando os produtos por local.
EmailReport buildEmailReport({
  required String titulo,
  required DateTime data,
  required List<Produto> itens,
}) {
  final gerado = 'Gerado em ${du.formatDate(data)}';
  final total = 'Total: ${itens.length} produto(s)';

  // Agrupa por local preservando a ordem de aparicao.
  final grupos = <String, List<Produto>>{};
  for (final p in itens) {
    grupos.putIfAbsent(p.localNome, () => []).add(p);
  }

  // --- HTML (tabela completa) ---
  final h = StringBuffer();
  h.writeln('<!DOCTYPE html>');
  h.writeln(
    '<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;color:#222;">',
  );
  h.writeln('<div style="padding:16px;">');
  h.writeln(
    '<p style="margin:0 0 8px 0;font-size:16px;font-weight:bold;color:#4A8A1A;">${_esc(titulo)}</p>',
  );
  h.writeln(
    '<p style="margin:0 0 12px 0;font-size:12px;color:#555;">$gerado</p>',
  );
  h.writeln(
    '<table cellspacing="0" cellpadding="0" style="border-collapse:collapse;width:100%;font-size:12px;border:1px solid #7CB24B;">',
  );
  h.writeln('<tr style="background-color:#7CB24B;color:#ffffff;">');
  for (final col in ['Local', 'Qtd', 'Produto', 'Data', 'Situação', 'Status']) {
    final align = col == 'Qtd' ? 'center' : 'left';
    h.writeln(
      '<th style="padding:8px;text-align:$align;font-weight:bold;">$col</th>',
    );
  }
  h.writeln('</tr>');
  for (final p in itens) {
    h.writeln('<tr>');
    h.writeln(
      '<td style="padding:8px;border-top:1px solid #e0e0e0;">'
      '${_esc(p.localNome)}</td>',
    );
    h.writeln(
      '<td style="padding:8px;text-align:center;border-top:1px solid #e0e0e0;">'
      '${p.quantidade}</td>',
    );
    h.writeln(
      '<td style="padding:8px;border-top:1px solid #e0e0e0;">'
      '${_esc(p.nome)}</td>',
    );
    h.writeln(
      '<td style="padding:8px;border-top:1px solid #e0e0e0;">'
      '${_esc(du.formatShort(p.validade))}</td>',
    );
    h.writeln(
      '<td style="padding:8px;border-top:1px solid #e0e0e0;">'
      '${_esc(p.situacao.isEmpty ? '-' : p.situacao)}</td>',
    );
    h.writeln(
      '<td style="padding:8px;border-top:1px solid #e0e0e0;">'
      '${_esc(p.status.isEmpty ? '-' : p.status)}</td>',
    );
    h.writeln('</tr>');
  }
  h.writeln('</table>');
  h.writeln(
    '<p style="margin:12px 0 0 0;font-size:12px;"><strong>$total</strong></p>',
  );
  h.writeln('</div></body></html>');

  // --- Rich (negrito + <br>, renderizado pelo Gmail) ---
  final r = StringBuffer();
  r.write('<b>${_esc(titulo)}</b><br>');
  r.write('$gerado<br><br>');
  grupos.forEach((local, lista) {
    r.write('<b>${_esc(local)}</b><br>');
    for (final p in lista) {
      final ss = _situacaoStatus(p);
      r.write(
        '&#8226; ${_esc(p.nome)} &mdash; Qtd ${p.quantidade} '
        '&mdash; ${_esc(du.formatShort(p.validade))}',
      );
      if (ss.isNotEmpty) r.write(' &mdash; ${_esc(ss)}');
      r.write('<br>');
    }
    r.write('<br>');
  });
  r.write('<b>$total</b>');

  // --- Plain ---
  final p = StringBuffer();
  p.writeln(titulo);
  p.writeln(gerado);
  p.writeln('');
  grupos.forEach((local, lista) {
    p.writeln(local);
    for (final prod in lista) {
      final ss = _situacaoStatus(prod);
      final base =
          '  • ${prod.nome} — Qtd ${prod.quantidade} '
          '— ${du.formatShort(prod.validade)}';
      p.writeln(ss.isEmpty ? base : '$base — $ss');
    }
    p.writeln('');
  });
  p.write(total);

  return EmailReport(
    html: h.toString(),
    rich: r.toString(),
    plain: p.toString(),
  );
}
