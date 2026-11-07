import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

/// PBKDF2-HMAC-SHA256: transforma uma senha (ou PIN) numa chave de 256 bits.
/// É propositalmente lento, para dificultar tentar muitas senhas.
///
/// Por padrão roda em outro "isolate", para não congelar a tela enquanto calcula.
Future<List<int>> derivarChave(
  String senha,
  List<int> sal,
  int iteracoes, {
  bool isolado = true,
}) {
  Future<List<int>> calcular() async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iteracoes,
      bits: 256,
    );
    final chave = await pbkdf2.deriveKeyFromPassword(password: senha, nonce: sal);
    return chave.extractBytes();
  }

  return isolado ? Isolate.run(calcular) : calcular();
}

/// Compara dois conjuntos de bytes em tempo constante.
bool bytesIguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diferenca = 0;
  for (var i = 0; i < a.length; i++) {
    diferenca |= a[i] ^ b[i];
  }
  return diferenca == 0;
}
