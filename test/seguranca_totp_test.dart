import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/base32.dart';
import 'package:prep_manager/seguranca/totp.dart';

void main() {
  group('Base32 (vetores da RFC 4648)', () {
    const vetores = {
      '': '',
      'f': 'MY',
      'fo': 'MZXQ',
      'foo': 'MZXW6',
      'foob': 'MZXW6YQ',
      'fooba': 'MZXW6YTB',
      'foobar': 'MZXW6YTBOI',
    };

    test('codifica', () {
      vetores.forEach((texto, esperado) {
        expect(Base32.codificar(utf8.encode(texto)), esperado);
      });
    });

    test('decodifica (aceita minúsculas, espaços e hífens)', () {
      vetores.forEach((texto, codificado) {
        expect(utf8.decode(Base32.decodificar(codificado)), texto);
      });
      expect(utf8.decode(Base32.decodificar('mzxw 6ytb-oi')), 'foobar');
    });

    test('caractere inválido lança erro', () {
      expect(() => Base32.decodificar('MZXW1'), throwsA(isA<FormatException>()));
    });

    test('ida e volta com bytes aleatórios', () {
      final bytes = List<int>.generate(37, (i) => (i * 73 + 11) % 256);
      expect(Base32.decodificar(Base32.codificar(bytes)), bytes);
    });
  });

  group('TOTP (vetores da RFC 6238, SHA-1, 8 dígitos)', () {
    final segredo = Base32.codificar(utf8.encode('12345678901234567890'));

    DateTime em(int segundos) =>
        DateTime.fromMillisecondsSinceEpoch(segundos * 1000, isUtc: true);

    test('o segredo da RFC vira o Base32 esperado', () {
      expect(segredo, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    });

    test('códigos oficiais', () {
      const vetores = {
        59: '94287082',
        1111111109: '07081804',
        1111111111: '14050471',
        1234567890: '89005924',
        2000000000: '69279037',
        20000000000: '65353130',
      };
      vetores.forEach((segundos, esperado) {
        final passo = Totp.passoDe(em(segundos));
        expect(Totp.codigo(segredo, passo, numeroDigitos: 8), esperado);
      });
    });

    test('com 6 dígitos são os 6 últimos dos oficiais', () {
      expect(Totp.codigo(segredo, Totp.passoDe(em(59))), '287082');
      expect(Totp.codigo(segredo, Totp.passoDe(em(1111111109))), '081804');
    });
  });

  group('Totp.verificar', () {
    const segredo = 'JBSWY3DPEHPK3PXP';
    final agora = DateTime.utc(2026, 11, 4, 12, 0, 10);
    final passo = Totp.passoDe(agora);

    test('aceita o código do passo atual', () {
      final c = Totp.codigo(segredo, passo);
      expect(Totp.verificar(segredo, c, agora: agora), passo);
    });

    test('aceita um passo antes e um depois (relógios diferentes)', () {
      expect(Totp.verificar(segredo, Totp.codigo(segredo, passo - 1), agora: agora), passo - 1);
      expect(Totp.verificar(segredo, Totp.codigo(segredo, passo + 1), agora: agora), passo + 1);
    });

    test('recusa dois passos de diferença', () {
      expect(Totp.verificar(segredo, Totp.codigo(segredo, passo - 2), agora: agora), isNull);
      expect(Totp.verificar(segredo, Totp.codigo(segredo, passo + 2), agora: agora), isNull);
    });

    test('o mesmo código não vale duas vezes', () {
      final c = Totp.codigo(segredo, passo);
      final usado = Totp.verificar(segredo, c, agora: agora);
      expect(usado, passo);
      expect(Totp.verificar(segredo, c, agora: agora, ultimoPassoUsado: usado), isNull);
      // nem um código mais antigo que o já usado
      expect(
        Totp.verificar(segredo, Totp.codigo(segredo, passo - 1),
            agora: agora, ultimoPassoUsado: usado),
        isNull,
      );
    });

    test('recusa formato inválido e aceita espaços', () {
      expect(Totp.verificar(segredo, '12345', agora: agora), isNull);
      expect(Totp.verificar(segredo, 'abcdef', agora: agora), isNull);
      final c = Totp.codigo(segredo, passo);
      expect(Totp.verificar(segredo, '${c.substring(0, 3)} ${c.substring(3)}', agora: agora), passo);
    });

    test('segredo gerado tem 32 caracteres e é diferente a cada vez', () {
      final a = Totp.gerarSegredo();
      final b = Totp.gerarSegredo();
      expect(a.length, 32);
      expect(a == b, isFalse);
      expect(Base32.decodificar(a).length, 20);
    });

    test('o endereço do QR Code tem os campos certos', () {
      final u = Totp.uri(segredo: segredo, conta: 'Meu celular', emissor: 'Despensa Digital');
      expect(u.startsWith('otpauth://totp/Despensa%20Digital:Meu%20celular?'), isTrue);
      expect(u.contains('secret=$segredo'), isTrue);
      expect(u.contains('digits=6'), isTrue);
      expect(u.contains('period=30'), isTrue);
    });
  });
}
