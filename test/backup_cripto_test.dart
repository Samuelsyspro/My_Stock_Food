import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/backup_cripto.dart';

void main() {
  const texto = '{"app":"prep_manager","itens":[{"nome":"Água mineral","quantidade":12}]}';
  const senha = 'minha-senha-forte';
  const rapido = 2000; // iterações só para teste (no app são 300.000)

  Future<BackupCifrado> proteger({
    String t = texto,
    String s = senha,
    bool codigo = true,
    bool isolado = false,
  }) =>
      BackupProtegido.proteger(t, s,
          gerarCodigoRecuperacao: codigo, iteracoes: rapido, isolado: isolado);

  group('regras da senha', () {
    test('mínimo de 8 caracteres e não pode ser repetitiva', () {
      expect(BackupProtegido.validarSenha('curta'), isNotNull);
      expect(BackupProtegido.validarSenha('aaaaaaaaaa'), isNotNull);
      expect(BackupProtegido.validarSenha('abababab'), isNotNull);
      expect(BackupProtegido.validarSenha('minha-senha-forte'), isNull);
    });

    test('proteger recusa senha fraca', () async {
      await expectLater(proteger(s: '123'), throwsA(isA<BackupException>()));
    });
  });

  group('proteger e abrir', () {
    test('ida e volta com a senha', () async {
      final b = await proteger();
      final aberto = await BackupProtegido.abrir(b.texto, senha: senha, isolado: false);
      expect(aberto, texto);
    });

    test('funciona também calculando em outro isolate', () async {
      final b = await proteger(isolado: true);
      expect(await BackupProtegido.abrir(b.texto, senha: senha), texto);
    });

    test('o conteúdo não aparece em texto no backup protegido', () async {
      final b = await proteger();
      expect(b.texto.contains('Água'), isFalse);
      expect(b.texto.contains('mineral'), isFalse);
      expect(b.texto.contains('itens'), isFalse);
      expect(b.texto.contains(senha), isFalse);
    });

    test('senha errada é recusada com mensagem clara', () async {
      final b = await proteger();
      await expectLater(
        BackupProtegido.abrir(b.texto, senha: 'outra-senha-qualquer', isolado: false),
        throwsA(isA<BackupException>()),
      );
      try {
        await BackupProtegido.abrir(b.texto, senha: 'outra-senha-qualquer', isolado: false);
      } on BackupException catch (e) {
        expect(e.mensagem.contains('Senha incorreta'), isTrue);
      }
    });

    test('sem senha nem código, pede a senha', () async {
      final b = await proteger();
      await expectLater(BackupProtegido.abrir(b.texto), throwsA(isA<BackupException>()));
    });

    test('cada backup é diferente, mesmo com os mesmos dados e senha', () async {
      final a = await proteger();
      final b = await proteger();
      expect(a.texto == b.texto, isFalse);
    });

    test('texto que não é backup protegido é recusado', () async {
      await expectLater(BackupProtegido.abrir('abc', senha: senha), throwsA(isA<BackupException>()));
      await expectLater(BackupProtegido.abrir('{"app":"prep_manager"}', senha: senha),
          throwsA(isA<BackupException>()));
    });

    test('ehProtegido reconhece só o formato novo', () async {
      final b = await proteger();
      expect(BackupProtegido.ehProtegido(b.texto), isTrue);
      expect(BackupProtegido.ehProtegido(texto), isFalse);
      expect(BackupProtegido.ehProtegido('lixo'), isFalse);
    });
  });

  group('código de recuperação', () {
    test('é gerado só quando pedido', () async {
      expect((await proteger()).codigoRecuperacao, isNotNull);
      expect((await proteger(codigo: false)).codigoRecuperacao, isNull);
      expect(BackupProtegido.temCodigoRecuperacao((await proteger()).texto), isTrue);
      expect(BackupProtegido.temCodigoRecuperacao((await proteger(codigo: false)).texto), isFalse);
    });

    test('tem o formato XXXX-XXXX-... (8 grupos), fácil de anotar', () async {
      final c = (await proteger()).codigoRecuperacao!;
      expect(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$').hasMatch(c), isTrue, reason: c);
    });

    test('abre o backup mesmo sem a senha', () async {
      final b = await proteger();
      final aberto = await BackupProtegido.abrir(b.texto, codigoRecuperacao: b.codigoRecuperacao);
      expect(aberto, texto);
    });

    test('aceita o código em minúsculas e sem hífens', () async {
      final b = await proteger();
      final digitado = b.codigoRecuperacao!.replaceAll('-', '').toLowerCase();
      expect(await BackupProtegido.abrir(b.texto, codigoRecuperacao: digitado), texto);
    });

    test('código errado é recusado', () async {
      final b = await proteger();
      final outro = (await proteger()).codigoRecuperacao;
      await expectLater(BackupProtegido.abrir(b.texto, codigoRecuperacao: outro),
          throwsA(isA<BackupException>()));
      await expectLater(BackupProtegido.abrir(b.texto, codigoRecuperacao: 'ABC'),
          throwsA(isA<BackupException>()));
      await expectLater(BackupProtegido.abrir(b.texto, codigoRecuperacao: '!!!!'),
          throwsA(isA<BackupException>()));
    });

    test('backup sem código de recuperação não abre com código', () async {
      final b = await proteger(codigo: false);
      final outro = (await proteger()).codigoRecuperacao;
      await expectLater(BackupProtegido.abrir(b.texto, codigoRecuperacao: outro),
          throwsA(isA<BackupException>()));
    });
  });

  group('adulteração', () {
    Map<String, dynamic> mapaDe(String t) => jsonDecode(t) as Map<String, dynamic>;

    String alterarUmByte(String base64Texto) {
      final bytes = base64Decode(base64Texto);
      bytes[bytes.length ~/ 2] ^= 0x01;
      return base64Encode(bytes);
    }

    test('alterar os dados faz o backup ser recusado', () async {
      final b = await proteger();
      final m = mapaDe(b.texto);
      m['dados'] = alterarUmByte(m['dados'] as String);
      await expectLater(
        BackupProtegido.abrir(jsonEncode(m), senha: senha, isolado: false),
        throwsA(isA<BackupException>()),
      );
    });

    test('alterar a chave trancada faz o backup ser recusado', () async {
      final b = await proteger();
      final m = mapaDe(b.texto);
      m['senha']['chave'] = alterarUmByte(m['senha']['chave'] as String);
      await expectLater(
        BackupProtegido.abrir(jsonEncode(m), senha: senha, isolado: false),
        throwsA(isA<BackupException>()),
      );
    });

    test('número de iterações absurdo é recusado (evita travar o app)', () async {
      final b = await proteger();
      final m = mapaDe(b.texto);
      m['kdf']['iteracoes'] = 999999999;
      await expectLater(
        BackupProtegido.abrir(jsonEncode(m), senha: senha, isolado: false),
        throwsA(isA<BackupException>()),
      );
    });

    test('versão desconhecida é recusada', () async {
      final b = await proteger();
      final m = mapaDe(b.texto);
      m['versao'] = 99;
      await expectLater(
        BackupProtegido.abrir(jsonEncode(m), senha: senha, isolado: false),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
