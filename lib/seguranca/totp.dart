import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:prep_manager/seguranca/base32.dart';

/// Códigos de 6 dígitos que mudam a cada 30 segundos (RFC 6238),
/// compatíveis com Google Authenticator, Microsoft Authenticator, Aegis, 2FAS etc.
class Totp {
  static const int periodo = 30;
  static const int digitos = 6;

  /// Segredo novo: 20 bytes aleatórios (160 bits) em Base32.
  static String gerarSegredo({Random? random}) {
    final r = random ?? Random.secure();
    return Base32.codificar(List<int>.generate(20, (_) => r.nextInt(256)));
  }

  /// Número do "passo" de 30 segundos em que [instante] está.
  static int passoDe(DateTime instante) =>
      instante.toUtc().millisecondsSinceEpoch ~/ 1000 ~/ periodo;

  /// Código de um passo.
  static String codigo(String segredoBase32, int passo, {int numeroDigitos = digitos}) {
    final chave = Base32.decodificar(segredoBase32);
    final contador = ByteData(8)..setUint64(0, passo, Endian.big);
    final hmac = Hmac(sha1, chave).convert(contador.buffer.asUint8List()).bytes;

    final deslocamento = hmac.last & 0x0f;
    final binario = ((hmac[deslocamento] & 0x7f) << 24) |
        ((hmac[deslocamento + 1] & 0xff) << 16) |
        ((hmac[deslocamento + 2] & 0xff) << 8) |
        (hmac[deslocamento + 3] & 0xff);

    final modulo = pow(10, numeroDigitos).toInt();
    return (binario % modulo).toString().padLeft(numeroDigitos, '0');
  }

  /// Confere o código digitado. Aceita o passo atual e [janela] passos para
  /// cada lado (relógios do celular e do autenticador nunca batem perfeitamente).
  ///
  /// Um passo já usado ([ultimoPassoUsado]) é recusado: o mesmo código não vale duas vezes.
  /// Devolve o passo aceito, ou null se o código estiver errado.
  static int? verificar(
    String segredoBase32,
    String codigoDigitado, {
    required DateTime agora,
    int? ultimoPassoUsado,
    int janela = 1,
  }) {
    final limpo = codigoDigitado.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(limpo)) return null;

    final atual = passoDe(agora);
    for (var deslocamento = -janela; deslocamento <= janela; deslocamento++) {
      final passo = atual + deslocamento;
      if (ultimoPassoUsado != null && passo <= ultimoPassoUsado) continue;
      if (_iguais(codigo(segredoBase32, passo), limpo)) return passo;
    }
    return null;
  }

  /// Endereço que o autenticador entende (usado no QR Code).
  static String uri({
    required String segredo,
    required String conta,
    required String emissor,
  }) {
    final e = Uri.encodeComponent(emissor);
    final c = Uri.encodeComponent(conta);
    return 'otpauth://totp/$e:$c?secret=$segredo&issuer=$e'
        '&algorithm=SHA1&digits=$digitos&period=$periodo';
  }

  // Comparação em tempo constante (não vaza em qual dígito errou)
  static bool _iguais(String a, String b) {
    if (a.length != b.length) return false;
    var diferenca = 0;
    for (var i = 0; i < a.length; i++) {
      diferenca |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diferenca == 0;
  }
}
