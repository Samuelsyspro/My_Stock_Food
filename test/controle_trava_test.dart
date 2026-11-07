import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/controle_trava.dart';

void main() {
  group('deveTravarAoVoltar', () {
    test('trava só depois do tempo configurado', () {
      expect(deveTravarAoVoltar(const Duration(seconds: 5), 10), isFalse);
      expect(deveTravarAoVoltar(const Duration(seconds: 9, milliseconds: 999), 10), isFalse);
      expect(deveTravarAoVoltar(const Duration(seconds: 10), 10), isTrue);
      expect(deveTravarAoVoltar(const Duration(minutes: 3), 10), isTrue);
    });

    test('com 0 segundos, trava sempre que voltar', () {
      expect(deveTravarAoVoltar(Duration.zero, 0), isTrue);
      expect(deveTravarAoVoltar(const Duration(milliseconds: 200), 0), isTrue);
    });
  });

  group('formatarEspera', () {
    test('minutos e segundos', () {
      expect(formatarEspera(const Duration(seconds: 27)), '0:27');
      expect(formatarEspera(const Duration(minutes: 1)), '1:00');
      expect(formatarEspera(const Duration(minutes: 4, seconds: 59)), '4:59');
    });

    test('arredonda para cima (nunca mostra 0:00 enquanto ainda espera)', () {
      expect(formatarEspera(const Duration(milliseconds: 400)), '0:01');
      expect(formatarEspera(const Duration(seconds: 29, milliseconds: 100)), '0:30');
    });

    test('horas', () {
      expect(formatarEspera(const Duration(hours: 1)), '1 h 00 min');
      expect(formatarEspera(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
    });

    test('negativo vira 0:00', () {
      expect(formatarEspera(const Duration(seconds: -3)), '0:00');
    });
  });
}
