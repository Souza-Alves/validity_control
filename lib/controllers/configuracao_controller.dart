import '../storage/storage.dart' as storage;

/// Controller da tela de Configurações: ações sobre a base de dados.
class ConfiguracaoController {
  const ConfiguracaoController();

  Future<void> clearAll() => storage.clearAllData();
}
