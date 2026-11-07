/// Onde guardamos segredos (hash do PIN, chave dos dados, segredo do 2FA...).
///
/// No celular, a implementação usa o cofre do Android (Keystore).
/// Nos testes, usa a memória. Assim a lógica pode ser testada sem o celular.
abstract class ArmazenamentoSeguro {
  Future<String?> ler(String chave);
  Future<void> gravar(String chave, String valor);
  Future<void> apagar(String chave);
}

/// Versão em memória, usada nos testes.
class ArmazenamentoMemoria implements ArmazenamentoSeguro {
  final Map<String, String> dados = {};

  @override
  Future<String?> ler(String chave) async => dados[chave];

  @override
  Future<void> gravar(String chave, String valor) async => dados[chave] = valor;

  @override
  Future<void> apagar(String chave) async => dados.remove(chave);
}
