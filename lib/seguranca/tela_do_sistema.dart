/// Controla quando o app abriu uma tela do PRÓPRIO sistema (digital, rosto,
/// bloqueio do celular, escolher/salvar arquivo...).
///
/// Nesses momentos o app vai para "segundo plano" de propósito, e a trava
/// não deve cobrir a tela nem pedir o PIN de novo na volta.
class TelaDoSistema {
  TelaDoSistema._();

  static int _abertas = 0;

  /// Tem alguma tela do sistema aberta agora?
  static bool get aberta => _abertas > 0;

  /// Executa [acao] marcando que uma tela do sistema está aberta.
  static Future<T> enquanto<T>(Future<T> Function() acao) async {
    _abertas++;
    try {
      return await acao();
    } finally {
      // Espera um pouco: o aviso de "voltou ao primeiro plano" pode chegar
      // logo depois da resposta da tela do sistema.
      Future.delayed(const Duration(seconds: 1), () => _abertas--);
    }
  }
}
