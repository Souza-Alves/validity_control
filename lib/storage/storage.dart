import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local.dart';
import '../models/produto.dart';
import '../supabase/supabase_client.dart';
import '../utils/id.dart';

const _storageKey = 'controle_validades_data';
const _queueKey = 'controle_validades_queue';
const _migratedKey = 'controle_validades_migrated';

final ValueNotifier<int> dataChanged = ValueNotifier<int>(0);

void _notifyDataChanged() {
  dataChanged.value += 1;
}

// =================== Cache local (offline) ===================

class _WorkbookData {
  List<Local> locais;
  List<Produto> produtos;
  _WorkbookData({required this.locais, required this.produtos});

  Map<String, dynamic> toJson() => {
    'locais': locais.map((l) => l.toJson()).toList(),
    'produtos': produtos.map((p) => p.toJson()).toList(),
  };

  factory _WorkbookData.fromJson(Map<String, dynamic> json) {
    final locaisList =
        (json['locais'] as List<dynamic>?)
            ?.map((e) => Local.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final produtosList =
        (json['produtos'] as List<dynamic>?)
            ?.map((e) => Produto.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return _WorkbookData(locais: locaisList, produtos: produtosList);
  }
}

Future<String> _getFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/controle_validades.json';
}

Future<_WorkbookData> _readWorkbook() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null) return _WorkbookData(locais: [], produtos: []);
    return _WorkbookData.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }
  final file = File(await _getFilePath());
  if (!await file.exists()) return _WorkbookData(locais: [], produtos: []);
  final content = await file.readAsString();
  if (content.isEmpty) return _WorkbookData(locais: [], produtos: []);
  return _WorkbookData.fromJson(jsonDecode(content) as Map<String, dynamic>);
}

Future<void> _writeWorkbook(_WorkbookData data) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
    return;
  }
  final file = File(await _getFilePath());
  await file.writeAsString(jsonEncode(data.toJson()));
}

// =================== Fila de operações pendentes ===================
//
// Cada op é um Map serializável: { 'kind': ..., 'data'|'id': ... }

Future<String> _getQueuePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/controle_validades_queue.json';
}

Future<List<Map<String, dynamic>>> _readQueue() async {
  try {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_queueKey);
      if (stored == null) return [];
      return (jsonDecode(stored) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    final file = File(await _getQueuePath());
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    return (jsonDecode(content) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(queue));
    return;
  }
  final file = File(await _getQueuePath());
  await file.writeAsString(jsonEncode(queue));
}

Future<void> _enqueue(Map<String, dynamic> op) async {
  final queue = await _readQueue();
  queue.add(op);
  await _writeQueue(queue);
  unawaited(_ensureSynced(force: true));
}

Future<bool> _getFlag(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) ?? false;
}

Future<void> _setFlag(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, true);
}

// =================== Mapeamento app <-> Supabase ===================
// tb_location: id(int8), name(varchar), status(bool)
// tb_products: id(int8), name(varchar), amount(int4), exp_date(date),
//              situation(varchar), status(varchar), id_location(int8 FK)

String? _appDateToDb(String d) {
  if (d.isEmpty) return null;
  final parts = d.split('/');
  if (parts.length != 3) return null;
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}

String _dbDateToApp(String? d) {
  if (d == null || d.isEmpty) return '';
  // Aceita 'YYYY-MM-DD' (eventual 'YYYY-MM-DDTHH:...').
  final datePart = d.split('T').first;
  final parts = datePart.split('-');
  if (parts.length != 3) return d;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

Map<String, dynamic> _toDbLocal(Local l) => {
  'id': int.tryParse(l.id) ?? 0,
  'name': l.nome,
  'status': l.ativo,
};

Local _fromDbLocal(Map<String, dynamic> r) => Local(
  id: r['id'].toString(),
  nome: (r['name'] ?? '').toString(),
  ativo: r['status'] == true,
);

Map<String, dynamic> _toDbProduto(Produto p) => {
  'id': int.tryParse(p.id) ?? 0,
  'name': p.nome,
  'amount': p.quantidade,
  'exp_date': _appDateToDb(p.validade),
  'situation': p.situacao,
  'status': p.status,
  'id_location': int.tryParse(p.localId) ?? 0,
};

Produto _fromDbProduto(Map<String, dynamic> r) {
  final loc = r['tb_location'];
  final localNome = loc is Map<String, dynamic>
      ? (loc['name'] ?? '').toString()
      : '';
  return Produto(
    id: r['id'].toString(),
    localId: (r['id_location'] ?? '').toString(),
    localNome: localNome,
    quantidade: r['amount'] is int
        ? r['amount'] as int
        : int.tryParse(r['amount']?.toString() ?? '0') ?? 0,
    nome: (r['name'] ?? '').toString(),
    validade: _dbDateToApp(r['exp_date']?.toString()),
    situacao: (r['situation'] ?? '').toString(),
    status: (r['status'] ?? '').toString(),
  );
}

// =================== Sincronização ===================

Future<void>? _inFlight;
int _lastSyncAt = 0;
bool _wasConnected = true;
bool _listenerStarted = false;

Future<bool> isOnline() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}

void _startConnectivityListener() {
  if (_listenerStarted) return;
  _listenerStarted = true;
  Connectivity().onConnectivityChanged.listen((results) {
    final connected = !results.contains(ConnectivityResult.none);
    if (connected && !_wasConnected) {
      unawaited(_ensureSynced(force: true));
    }
    _wasConnected = connected;
  });
}

Future<void> _applyOp(Map<String, dynamic> op) async {
  final kind = op['kind'] as String;
  switch (kind) {
    case 'upsertLocal':
      await supabase
          .from('tb_location')
          .upsert(
            _toDbLocal(Local.fromJson(op['data'] as Map<String, dynamic>)),
          );
    case 'deleteLocal':
      await supabase
          .from('tb_location')
          .delete()
          .eq('id', int.tryParse(op['id'].toString()) ?? 0);
    case 'upsertProduto':
      await supabase
          .from('tb_products')
          .upsert(
            _toDbProduto(Produto.fromJson(op['data'] as Map<String, dynamic>)),
          );
    case 'deleteProduto':
      await supabase
          .from('tb_products')
          .delete()
          .eq('id', int.tryParse(op['id'].toString()) ?? 0);
    case 'clearAll':
      await supabase.from('tb_products').delete().neq('id', 0);
      await supabase.from('tb_location').delete().neq('id', 0);
  }
}

bool _isNumericId(String id) => int.tryParse(id) != null;

Future<void> _ensureMigration() async {
  if (await _getFlag(_migratedKey)) return;
  var local = await _readWorkbook();
  if (local.locais.isNotEmpty || local.produtos.isNotEmpty) {
    // Re-chaveia IDs nao-numericos (ex.: UUIDs de versoes antigas do app) para
    // IDs numericos compativeis com int8, remapeando as FKs dos produtos. Sem
    // isso, int.tryParse(uuid) ?? 0 jogaria todos os registros para id=0,
    // colidindo entre si no Supabase e perdendo dados na migracao.
    final localIdRemap = <String, String>{};
    final locaisRekey = <Local>[];
    for (final l in local.locais) {
      final newId = _isNumericId(l.id) ? l.id : generateId();
      if (newId != l.id) localIdRemap[l.id] = newId;
      locaisRekey.add(Local(id: newId, nome: l.nome, ativo: l.ativo));
    }
    final produtosRekey = <Produto>[];
    for (final p in local.produtos) {
      final newId = _isNumericId(p.id) ? p.id : generateId();
      final newLocalId =
          localIdRemap[p.localId] ??
          (_isNumericId(p.localId) ? p.localId : '0');
      produtosRekey.add(
        Produto(
          id: newId,
          localId: newLocalId,
          localNome: p.localNome,
          quantidade: p.quantidade,
          nome: p.nome,
          validade: p.validade,
          situacao: p.situacao,
          status: p.status,
        ),
      );
    }
    // Persiste os IDs re-chaveados no cache local para manter consistencia
    // entre o que o app mostra e o que sera enviado ao Supabase.
    local = _WorkbookData(locais: locaisRekey, produtos: produtosRekey);
    await _writeWorkbook(local);

    final queue = await _readQueue();
    for (final l in local.locais) {
      queue.add({'kind': 'upsertLocal', 'data': l.toJson()});
    }
    for (final p in local.produtos) {
      queue.add({'kind': 'upsertProduto', 'data': p.toJson()});
    }
    await _writeQueue(queue);
  }
  await _setFlag(_migratedKey);
}

Future<void> _doSync() async {
  if (!await isOnline()) return;

  await _ensureMigration();

  // Processa a fila um item por vez, relendo do disco após cada operação para
  // não sobrescrever itens que outro código async adicionou enquanto a chamada
  // de rede (lenta) do applyOp estava em andamento.
  while (true) {
    final queue = await _readQueue();
    if (queue.isEmpty) break;
    await _applyOp(queue.first);
    final current = await _readQueue();
    if (current.isNotEmpty) current.removeAt(0);
    await _writeQueue(current);
  }

  final locaisRes = await supabase.from('tb_location').select('*');
  final produtosRes = await supabase
      .from('tb_products')
      .select('*, tb_location(name)');

  // Reverifica a fila antes de sobrescrever o cache: se novas ops foram
  // enfileiradas durante o fetch, pula a sobrescrita para não esconder
  // mudanças locais não sincronizadas. O próximo ciclo de sync as envia.
  final pending = await _readQueue();
  if (pending.isNotEmpty) return;

  final fresh = _WorkbookData(
    locais: (locaisRes as List<dynamic>)
        .map((e) => _fromDbLocal(e as Map<String, dynamic>))
        .toList(),
    produtos: (produtosRes as List<dynamic>)
        .map((e) => _fromDbProduto(e as Map<String, dynamic>))
        .toList(),
  );
  // So reescreve e notifica a UI quando o servidor traz algo diferente do
  // cache, evitando recarregamentos em loop a cada ciclo de sync.
  final freshJson = jsonEncode(fresh.toJson());
  final currentJson = jsonEncode((await _readWorkbook()).toJson());
  if (freshJson != currentJson) {
    await _writeWorkbook(fresh);
    _notifyDataChanged();
  }
}

Future<void> _ensureSynced({bool force = false}) {
  _startConnectivityListener();
  if (_inFlight != null) return _inFlight!;
  if (!force && DateTime.now().millisecondsSinceEpoch - _lastSyncAt < 800) {
    return Future.value();
  }
  _inFlight = () async {
    try {
      await _doSync();
    } catch (_) {
      // Sem rede ou falha temporária: mantém cache + fila.
    } finally {
      _lastSyncAt = DateTime.now().millisecondsSinceEpoch;
      _inFlight = null;
    }
  }();
  return _inFlight!;
}

Future<void> syncNow() => _ensureSynced(force: true);

// =================== Locais ===================

Future<List<Local>> getLocais() async {
  // Offline-first: devolve o cache na hora e sincroniza em segundo plano. Ao
  // terminar, _doSync notifica a UI se houver dados novos do servidor.
  unawaited(_ensureSynced());
  final data = await _readWorkbook();
  return data.locais;
}

Future<void> saveLocais(List<Local> locais) async {
  final data = await _readWorkbook();
  data.locais = locais;
  await _writeWorkbook(data);
  final queue = await _readQueue();
  for (final l in locais) {
    queue.add({'kind': 'upsertLocal', 'data': l.toJson()});
  }
  await _writeQueue(queue);
  unawaited(_ensureSynced(force: true));
  _notifyDataChanged();
}

Future<void> addLocal(Local local) async {
  final data = await _readWorkbook();
  data.locais.add(local);
  await _writeWorkbook(data);
  await _enqueue({'kind': 'upsertLocal', 'data': local.toJson()});
  _notifyDataChanged();
}

Future<void> updateLocal(Local updated) async {
  final data = await _readWorkbook();
  final index = data.locais.indexWhere((l) => l.id == updated.id);
  if (index < 0) return;
  final anterior = data.locais[index];
  data.locais[index] = updated;
  // Cascata: ao renomear o local, atualiza o nome em todos os seus produtos.
  if (anterior.nome != updated.nome) {
    for (final p in data.produtos) {
      if (p.localId == updated.id) p.localNome = updated.nome;
    }
  }
  await _writeWorkbook(data);
  await _enqueue({'kind': 'upsertLocal', 'data': updated.toJson()});
  _notifyDataChanged();
}

Future<void> deleteLocal(String id) async {
  final data = await _readWorkbook();
  data.locais.removeWhere((l) => l.id == id);
  await _writeWorkbook(data);
  await _enqueue({'kind': 'deleteLocal', 'id': id});
  _notifyDataChanged();
}

Future<List<Local>> getLocaisAtivos() async {
  unawaited(_ensureSynced());
  final data = await _readWorkbook();
  return data.locais.where((l) => l.ativo).toList();
}

// =================== Produtos ===================

Future<List<Produto>> getProdutos() async {
  unawaited(_ensureSynced());
  final data = await _readWorkbook();
  return data.produtos;
}

Future<void> saveProdutos(List<Produto> produtos) async {
  final data = await _readWorkbook();
  data.produtos = produtos;
  await _writeWorkbook(data);
  final queue = await _readQueue();
  for (final p in produtos) {
    queue.add({'kind': 'upsertProduto', 'data': p.toJson()});
  }
  await _writeQueue(queue);
  unawaited(_ensureSynced(force: true));
  _notifyDataChanged();
}

Future<void> addProduto(Produto produto) async {
  final data = await _readWorkbook();
  data.produtos.add(produto);
  await _writeWorkbook(data);
  await _enqueue({'kind': 'upsertProduto', 'data': produto.toJson()});
  _notifyDataChanged();
}

Future<void> addProdutos(List<Produto> newProdutos) async {
  final data = await _readWorkbook();
  data.produtos.addAll(newProdutos);
  await _writeWorkbook(data);
  final queue = await _readQueue();
  for (final p in newProdutos) {
    queue.add({'kind': 'upsertProduto', 'data': p.toJson()});
  }
  await _writeQueue(queue);
  unawaited(_ensureSynced(force: true));
  _notifyDataChanged();
}

/// Grava todos os locais + produtos de uma vez (uma única escrita no cache e
/// uma única sincronização no final) — usado na importação em massa.
Future<void> importBatch(List<Local> locais, List<Produto> produtos) async {
  final data = await _readWorkbook();
  for (final l in locais) {
    if (!data.locais.any((x) => x.id == l.id)) data.locais.add(l);
  }
  data.produtos.addAll(produtos);
  await _writeWorkbook(data);
  final queue = await _readQueue();
  for (final l in locais) {
    queue.add({'kind': 'upsertLocal', 'data': l.toJson()});
  }
  for (final p in produtos) {
    queue.add({'kind': 'upsertProduto', 'data': p.toJson()});
  }
  await _writeQueue(queue);
  unawaited(_ensureSynced(force: true));
  _notifyDataChanged();
}

Future<void> updateProduto(Produto updated) async {
  final data = await _readWorkbook();
  final index = data.produtos.indexWhere((p) => p.id == updated.id);
  if (index < 0) return;
  data.produtos[index] = updated;
  await _writeWorkbook(data);
  await _enqueue({'kind': 'upsertProduto', 'data': updated.toJson()});
  _notifyDataChanged();
}

Future<void> deleteProduto(String id) async {
  final data = await _readWorkbook();
  data.produtos.removeWhere((p) => p.id == id);
  await _writeWorkbook(data);
  await _enqueue({'kind': 'deleteProduto', 'id': id});
  _notifyDataChanged();
}

Future<void> clearAllData() async {
  await _writeWorkbook(_WorkbookData(locais: [], produtos: []));
  await _writeQueue([
    {'kind': 'clearAll'},
  ]);
  unawaited(_ensureSynced(force: true));
  _notifyDataChanged();
}
