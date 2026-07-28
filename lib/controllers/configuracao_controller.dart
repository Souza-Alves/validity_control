import '../storage/storage.dart' as storage;

/// Controller da tela de Configurações: ações sobre a base de dados.
class ConfiguracaoController {
  const ConfiguracaoController();

  Future<void> clearAll() => storage.clearAllData();

  /// Períodos (ano/mês) disponíveis nos produtos, mais recentes primeiro.
  Future<List<({int ano, int mes})>> periodosDisponiveis() =>
      storage.periodosDisponiveis();

  /// Apaga os produtos de um mês/ano. Retorna quantos foram removidos.
  Future<int> apagarPeriodo(int ano, int mes) =>
      storage.deleteProdutosPorPeriodo(ano, mes);
}
