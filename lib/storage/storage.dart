import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local.dart';
import '../models/produto.dart';

const _storageKey = 'controle_validades_data';

class _WorkbookData {
  List<Local> locais;
  List<Produto> produtos;
  _WorkbookData({required this.locais, required this.produtos});

  Map<String, dynamic> toJson() => {
        'locais': locais.map((l) => l.toJson()).toList(),
        'produtos': produtos.map((p) => p.toJson()).toList(),
      };

  factory _WorkbookData.fromJson(Map<String, dynamic> json) {
    final locaisList = (json['locais'] as List<dynamic>?)
            ?.map((e) => Local.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final produtosList = (json['produtos'] as List<dynamic>?)
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

Future<_WorkbookData> _readData() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null) return _WorkbookData(locais: [], produtos: []);
    return _WorkbookData.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }
  final path = await _getFilePath();
  final file = File(path);
  if (!await file.exists()) return _WorkbookData(locais: [], produtos: []);
  final content = await file.readAsString();
  if (content.isEmpty) return _WorkbookData(locais: [], produtos: []);
  return _WorkbookData.fromJson(jsonDecode(content) as Map<String, dynamic>);
}

Future<void> _writeData(_WorkbookData data) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data.toJson()));
    return;
  }
  final path = await _getFilePath();
  final file = File(path);
  await file.writeAsString(jsonEncode(data.toJson()));
}

// --- Locais ---

Future<List<Local>> getLocais() async {
  final data = await _readData();
  return data.locais;
}

Future<void> saveLocais(List<Local> locais) async {
  final data = await _readData();
  data.locais = locais;
  await _writeData(data);
}

Future<void> addLocal(Local local) async {
  final data = await _readData();
  data.locais.add(local);
  await _writeData(data);
}

Future<void> updateLocal(Local updated) async {
  final data = await _readData();
  final index = data.locais.indexWhere((l) => l.id == updated.id);
  if (index >= 0) {
    data.locais[index] = updated;
    await _writeData(data);
  }
}

Future<void> deleteLocal(String id) async {
  final data = await _readData();
  data.locais.removeWhere((l) => l.id == id);
  await _writeData(data);
}

Future<List<Local>> getLocaisAtivos() async {
  final data = await _readData();
  return data.locais.where((l) => l.ativo).toList();
}

// --- Produtos ---

Future<List<Produto>> getProdutos() async {
  final data = await _readData();
  return data.produtos;
}

Future<void> saveProdutos(List<Produto> produtos) async {
  final data = await _readData();
  data.produtos = produtos;
  await _writeData(data);
}

Future<void> addProduto(Produto produto) async {
  final data = await _readData();
  data.produtos.add(produto);
  await _writeData(data);
}

Future<void> addProdutos(List<Produto> newProdutos) async {
  final data = await _readData();
  data.produtos.addAll(newProdutos);
  await _writeData(data);
}

Future<void> updateProduto(Produto updated) async {
  final data = await _readData();
  final index = data.produtos.indexWhere((p) => p.id == updated.id);
  if (index >= 0) {
    data.produtos[index] = updated;
    await _writeData(data);
  }
}

Future<void> deleteProduto(String id) async {
  final data = await _readData();
  data.produtos.removeWhere((p) => p.id == id);
  await _writeData(data);
}

Future<void> clearAllData() async {
  await _writeData(_WorkbookData(locais: [], produtos: []));
}
