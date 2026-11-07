/// Base32 (RFC 4648), o formato dos segredos de apps como o Google Authenticator.
class Base32 {
  static const String _alfabeto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Converte bytes em texto Base32, sem o "=" do final.
  static String codificar(List<int> bytes) {
    final saida = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xff);
      bits += 8;
      while (bits >= 5) {
        saida.write(_alfabeto[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) {
      saida.write(_alfabeto[(buffer << (5 - bits)) & 31]);
    }
    return saida.toString();
  }

  /// Converte texto Base32 em bytes. Aceita minúsculas, espaços, hífens e "=".
  /// Lança [FormatException] se houver um caractere inválido.
  static List<int> decodificar(String texto) {
    final limpo = texto.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    final bytes = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final caractere in limpo.split('')) {
      final valor = _alfabeto.indexOf(caractere);
      if (valor < 0) {
        throw FormatException('Caractere inválido: $caractere');
      }
      buffer = (buffer << 5) | valor;
      bits += 5;
      if (bits >= 8) {
        bytes.add((buffer >> (bits - 8)) & 0xff);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return bytes;
  }
}
