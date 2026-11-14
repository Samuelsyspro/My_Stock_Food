import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/backup_cripto.dart';

void main() {
  // 32 caracteres, todos do alfabeto do código (A-Z e 2-7)
  const codigo = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  String mensagemDe(void Function() acao) {
    try {
      acao();
    } on BackupException catch (e) {
      return e.mensagem;
    }
    fail('deveria ter lançado BackupException');
  }

  group('leiturasDoCodigo', () {
    test('código exato devolve uma única leitura', () {
      expect(BackupProtegido.leiturasDoCodigo(codigo), [codigo]);
    });

    test('ignora hífens, espaços, pontos, sublinhados e maiúsculas/minúsculas', () {
      expect(
        BackupProtegido.leiturasDoCodigo('abcd-efgh ijkl_mnop.qrst-uvwx-yz23-4567'),
        [codigo],
      );
    });

    test('0 vira O e 8 vira B', () {
      final anotado = codigo.replaceAll('O', '0').replaceAll('B', '8');
      expect(anotado.contains('0') && anotado.contains('8'), isTrue);
      expect(BackupProtegido.leiturasDoCodigo(anotado), [codigo]);
    });

    test('um "1" pode ser I ou L: duas leituras (a com I vem primeiro)', () {
      final anotado = codigo.replaceAll('I', '1'); // o L continua como está
      final leituras = BackupProtegido.leiturasDoCodigo(anotado);
      expect(leituras.length, 2);
      expect(leituras.first, codigo);
      expect(leituras.last, codigo.replaceAll('I', 'L'));
    });

    test('dois "1" geram quatro leituras, e uma delas é o código certo', () {
      final anotado = codigo.replaceAll('I', '1').replaceAll('L', '1');
      final leituras = BackupProtegido.leiturasDoCodigo(anotado);
      expect(leituras.length, 4);
      expect(leituras.contains(codigo), isTrue);
    });

    test('seis "1" ainda são aceitos (64 leituras)', () {
      final leituras = BackupProtegido.leiturasDoCodigo('111111ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(leituras.length, 64);
    });

    test('sete "1" são recusados com uma mensagem clara', () {
      final msg = mensagemDe(
        () => BackupProtegido.leiturasDoCodigo('1111111ABCDEFGHIJKLMNOPQRSTUVWXY'),
      );
      expect(msg.contains('letra I ou L'), isTrue, reason: msg);
    });

    test('caractere que não existe no código é recusado e citado na mensagem', () {
      final msg = mensagemDe(
        () => BackupProtegido.leiturasDoCodigo('${codigo.substring(0, 31)}9'),
      );
      expect(msg.contains('9'), isTrue, reason: msg);
      expect(msg.contains('2 a 7'), isTrue, reason: msg);
    });

    test('tamanho errado informa quantos caracteres foram digitados', () {
      expect(
        mensagemDe(() => BackupProtegido.leiturasDoCodigo(codigo.substring(0, 31))).contains('31'),
        isTrue,
      );
      expect(
        mensagemDe(() => BackupProtegido.leiturasDoCodigo('${codigo}A')).contains('33'),
        isTrue,
      );
    });
  });

  group('pareceCodigo', () {
    test('reconhece um código, com ou sem hífens', () {
      expect(BackupProtegido.pareceCodigo(codigo), isTrue);
      expect(BackupProtegido.pareceCodigo('ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567'), isTrue);
    });

    test('senhas comuns não parecem código', () {
      expect(BackupProtegido.pareceCodigo('minha-senha-forte'), isFalse);
      expect(BackupProtegido.pareceCodigo('senha-do-backup-123'), isFalse);
      expect(BackupProtegido.pareceCodigo(''), isFalse);
    });
  });
}
