import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/utils/helpers.dart';

void main() {
  group('normalizar', () {
    test('remove acentos, espaços e maiúsculas', () {
      expect(normalizar('  Água Mineral '), 'agua mineral');
      expect(normalizar('Ação'), 'acao');
      expect(normalizar('Açúcar'), 'acucar');
      expect(normalizar('ÔNIBUS'), 'onibus');
    });

    test('textos iguais sem acento são iguais depois de normalizar', () {
      expect(normalizar('água'), normalizar('AGUA'));
    });
  });

  group('formatarQuantidade', () {
    test('inteiro não mostra casa decimal', () {
      expect(formatarQuantidade(1), '1');
      expect(formatarQuantidade(12.0), '12');
      expect(formatarQuantidade(0), '0');
    });

    test('decimal usa vírgula e sem zeros sobrando', () {
      expect(formatarQuantidade(1.5), '1,5');
      expect(formatarQuantidade(0.25), '0,25');
      expect(formatarQuantidade(2.10), '2,1');
    });
  });

  group('somenteData', () {
    test('ignora a hora', () {
      final a = somenteData(DateTime(2026, 5, 10, 23, 59));
      final b = somenteData(DateTime(2026, 5, 10, 0, 1));
      expect(a, b);
    });
  });
}
