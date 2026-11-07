import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/seguranca/armazenamento_seguro.dart';
import 'package:prep_manager/seguranca/totp.dart';
import 'package:prep_manager/seguranca/trava_service.dart';

void main() {
  late ArmazenamentoMemoria st;
  late DateTime agora;

  TravaService novo({bool isolado = false}) => TravaService(
        st,
        agora: () => agora,
        iteracoesPin: 1000, // rápido para teste (no app são 100.000)
        isolado: isolado,
      );

  setUp(() {
    st = ArmazenamentoMemoria();
    agora = DateTime.utc(2026, 11, 4, 12);
  });

  group('regras do PIN', () {
    test('PIN válido tem de 4 a 6 dígitos', () {
      expect(TravaService.pinValido('1234'), isTrue);
      expect(TravaService.pinValido('123456'), isTrue);
      expect(TravaService.pinValido('123'), isFalse);
      expect(TravaService.pinValido('1234567'), isFalse);
      expect(TravaService.pinValido('12a4'), isFalse);
      expect(TravaService.pinValido(''), isFalse);
    });

    test('PIN fraco: dígitos iguais e sequências', () {
      for (final fraco in ['0000', '1111', '1234', '4321', '123456', '654321']) {
        expect(TravaService.pinFraco(fraco), isTrue, reason: fraco);
      }
      for (final bom in ['4827', '1357', '246810'.substring(0, 5), '9081']) {
        expect(TravaService.pinFraco(bom), isFalse, reason: bom);
      }
    });

    test('definir PIN inválido lança erro', () async {
      final t = novo();
      await expectLater(t.definirPin('12'), throwsA(isA<ArgumentError>()));
      expect(await t.pinConfigurado, isFalse);
    });
  });

  group('guardar e conferir o PIN', () {
    test('PIN certo entra, errado não', () async {
      final t = novo();
      await t.definirPin('4827');
      expect(await t.pinConfigurado, isTrue);
      expect((await t.verificarPin('4827')).correto, isTrue);
      expect((await t.verificarPin('4828')).correto, isFalse);
    });

    test('o PIN nunca é guardado como texto', () async {
      final t = novo();
      await t.definirPin('4827');
      for (final valor in st.dados.values) {
        expect(valor == '4827', isFalse);
        expect(valor.contains('4827'), isFalse);
      }
      expect(st.dados.containsKey('pin_hash'), isTrue);
      expect(st.dados.containsKey('pin_sal'), isTrue);
    });

    test('dois PINs iguais geram hashes diferentes (sal)', () async {
      await novo().definirPin('4827');
      final hash1 = st.dados['pin_hash'];
      await novo().definirPin('4827');
      expect(st.dados['pin_hash'] == hash1, isFalse);
    });

    test('funciona também calculando em outro isolate', () async {
      final t = novo(isolado: true);
      await t.definirPin('9081');
      expect((await t.verificarPin('9081')).correto, isTrue);
      expect((await t.verificarPin('0000')).correto, isFalse);
    });

    test('trocar o PIN invalida o antigo', () async {
      final t = novo();
      await t.definirPin('4827');
      await t.definirPin('9081');
      expect((await t.verificarPin('4827')).correto, isFalse);
      expect((await t.verificarPin('9081')).correto, isTrue);
    });
  });

  group('atraso progressivo', () {
    test('tabela de espera', () {
      expect(TravaService.esperaParaFalhas(1), Duration.zero);
      expect(TravaService.esperaParaFalhas(2), Duration.zero);
      expect(TravaService.esperaParaFalhas(3), const Duration(seconds: 30));
      expect(TravaService.esperaParaFalhas(4), const Duration(minutes: 1));
      expect(TravaService.esperaParaFalhas(5), const Duration(minutes: 5));
      expect(TravaService.esperaParaFalhas(6), const Duration(minutes: 15));
      expect(TravaService.esperaParaFalhas(7), const Duration(hours: 1));
      expect(TravaService.esperaParaFalhas(50), const Duration(hours: 1));
    });

    test('2 erros não esperam; o 3º trava por 30 segundos', () async {
      final t = novo();
      await t.definirPin('4827');

      expect((await t.verificarPin('1111')).espera, isNull);
      expect((await t.verificarPin('2222')).espera, isNull);
      final terceira = await t.verificarPin('3333');
      expect(terceira.correto, isFalse);
      expect(terceira.espera, const Duration(seconds: 30));
      expect(terceira.falhas, 3);
    });

    test('durante a espera nem o PIN certo é aceito', () async {
      final t = novo();
      await t.definirPin('4827');
      for (final errado in ['1111', '2222', '3333']) {
        await t.verificarPin(errado);
      }

      agora = agora.add(const Duration(seconds: 10));
      final r = await t.verificarPin('4827');
      expect(r.correto, isFalse);
      expect(r.avaliada, isFalse);
      expect(r.espera!.inSeconds, inInclusiveRange(19, 20));
    });

    test('depois da espera o PIN certo entra e zera a contagem', () async {
      final t = novo();
      await t.definirPin('4827');
      for (final errado in ['1111', '2222', '3333']) {
        await t.verificarPin(errado);
      }
      agora = agora.add(const Duration(seconds: 31));
      expect((await t.verificarPin('4827')).correto, isTrue);

      // contagem zerada: dois erros de novo não esperam
      expect((await t.verificarPin('1111')).espera, isNull);
      expect((await t.verificarPin('2222')).espera, isNull);
    });

    test('errar de novo depois da espera aumenta o tempo', () async {
      final t = novo();
      await t.definirPin('4827');
      for (final errado in ['1111', '2222', '3333']) {
        await t.verificarPin(errado);
      }
      agora = agora.add(const Duration(seconds: 31));
      final quarta = await t.verificarPin('4444');
      expect(quarta.espera, const Duration(minutes: 1));

      agora = agora.add(const Duration(seconds: 61));
      final quinta = await t.verificarPin('5555');
      expect(quinta.espera, const Duration(minutes: 5));
    });

    test('fechar e abrir o app não zera a espera', () async {
      final t1 = novo();
      await t1.definirPin('4827');
      for (final errado in ['1111', '2222', '3333']) {
        await t1.verificarPin(errado);
      }
      final t2 = novo(); // "app reaberto", mesmo armazenamento
      expect(await t2.esperaPinRestante(), isNotNull);
      expect((await t2.verificarPin('4827')).correto, isFalse);
    });
  });

  group('biometria e tempo para travar', () {
    test('biometria vem desligada e pode ser ligada', () async {
      final t = novo();
      expect(await t.biometriaAtiva, isFalse);
      await t.definirBiometria(true);
      expect(await t.biometriaAtiva, isTrue);
      await t.definirBiometria(false);
      expect(await t.biometriaAtiva, isFalse);
    });

    test('tempo para travar: padrão 10 s e pode mudar', () async {
      final t = novo();
      expect(await t.segundosParaTravar(), 10);
      await t.definirSegundosParaTravar(30);
      expect(await t.segundosParaTravar(), 30);
      await t.definirSegundosParaTravar(-5);
      expect(await t.segundosParaTravar(), 0);
    });
  });

  group('2FA (autenticador)', () {
    const segredo = 'JBSWY3DPEHPK3PXP';

    String codigoAgora([int deslocamento = 0]) =>
        Totp.codigo(segredo, Totp.passoDe(agora) + deslocamento);

    test('só ativa se o código digitado estiver certo', () async {
      final t = novo();
      expect(await t.doisFatoresAtivo, isFalse);
      expect(await t.ativarDoisFatores(segredo, '000000'), isFalse);
      expect(await t.doisFatoresAtivo, isFalse);
      expect(await t.ativarDoisFatores(segredo, codigoAgora()), isTrue);
      expect(await t.doisFatoresAtivo, isTrue);
    });

    test('depois de ativar, o código usado na ativação não vale de novo', () async {
      final t = novo();
      final c = codigoAgora();
      await t.ativarDoisFatores(segredo, c);
      expect((await t.verificarDoisFatores(c)).correto, isFalse);
    });

    test('código do próximo passo é aceito, uma única vez', () async {
      final t = novo();
      await t.ativarDoisFatores(segredo, codigoAgora());

      agora = agora.add(const Duration(seconds: 30));
      final c = codigoAgora();
      expect((await t.verificarDoisFatores(c)).correto, isTrue);
      expect((await t.verificarDoisFatores(c)).correto, isFalse);
    });

    test('erros de código também têm atraso progressivo', () async {
      final t = novo();
      await t.ativarDoisFatores(segredo, codigoAgora());
      agora = agora.add(const Duration(seconds: 30));

      await t.verificarDoisFatores('111111');
      await t.verificarDoisFatores('222222');
      final r = await t.verificarDoisFatores('333333');
      expect(r.espera, const Duration(seconds: 30));

      // o código certo, durante a espera, não é aceito
      final durante = await t.verificarDoisFatores(codigoAgora());
      expect(durante.correto, isFalse);
      expect(durante.avaliada, isFalse);
    });

    test('a contagem do 2FA é separada da do PIN', () async {
      final t = novo();
      await t.definirPin('4827');
      await t.ativarDoisFatores(segredo, codigoAgora());
      agora = agora.add(const Duration(seconds: 30));

      for (final e in ['1111', '2222', '3333']) {
        await t.verificarPin(e);
      }
      expect(await t.esperaPinRestante(), isNotNull);
      expect(await t.esperaDoisFatoresRestante(), isNull);
      expect((await t.verificarDoisFatores(codigoAgora())).correto, isTrue);
    });

    test('desativar apaga o segredo', () async {
      final t = novo();
      await t.ativarDoisFatores(segredo, codigoAgora());
      await t.desativarDoisFatores();
      expect(await t.doisFatoresAtivo, isFalse);
      expect(st.dados.containsKey('totp_segredo'), isFalse);
    });
  });
}
