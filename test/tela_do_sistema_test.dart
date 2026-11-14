import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/tela_do_sistema.dart';

/// Espera até o contador interno zerar (o TelaDoSistema só "fecha" 1 segundo
/// depois da ação terminar) para um teste não afetar o seguinte.
Future<void> esperarFechar() async {
  for (var i = 0; i < 60 && TelaDoSistema.aberta; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(esperarFechar);
  tearDown(esperarFechar);

  test('começa fechada', () {
    expect(TelaDoSistema.aberta, isFalse);
  });

  test('durante a ação está aberta', () async {
    bool? durante;
    await TelaDoSistema.enquanto(() async {
      durante = TelaDoSistema.aberta;
    });
    expect(durante, isTrue);
  });

  test('devolve o resultado da ação', () async {
    final resultado = await TelaDoSistema.enquanto(() async => 42);
    expect(resultado, 42);
  });

  test('continua aberta logo depois da ação e fecha cerca de 1 segundo depois', () async {
    await TelaDoSistema.enquanto(() async {});
    // o aviso de "voltou ao primeiro plano" pode chegar logo depois da ação
    expect(TelaDoSistema.aberta, isTrue);

    await Future.delayed(const Duration(milliseconds: 1300));
    expect(TelaDoSistema.aberta, isFalse);
  });

  test('se a ação falhar, o erro passa adiante e a marca ainda é desfeita', () async {
    await expectLater(
      TelaDoSistema.enquanto(() async => throw StateError('falhou')),
      throwsA(isA<StateError>()),
    );
    expect(TelaDoSistema.aberta, isTrue);

    await Future.delayed(const Duration(milliseconds: 1300));
    expect(TelaDoSistema.aberta, isFalse);
  });

  test('duas telas ao mesmo tempo: só fecha depois que as duas terminarem', () async {
    final curta = TelaDoSistema.enquanto(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    final longa = TelaDoSistema.enquanto(
      () => Future.delayed(const Duration(milliseconds: 800)),
    );
    await Future.wait([curta, longa]); // passou ~0,8 s

    // a curta já "fechou" (0,1 s + 1 s), mas a longa ainda não (0,8 s + 1 s)
    await Future.delayed(const Duration(milliseconds: 600)); // ~1,4 s
    expect(TelaDoSistema.aberta, isTrue);

    await Future.delayed(const Duration(milliseconds: 800)); // ~2,2 s
    expect(TelaDoSistema.aberta, isFalse);
  });
}
