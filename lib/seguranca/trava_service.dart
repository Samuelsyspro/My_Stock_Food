import 'dart:convert';
import 'dart:math';

import 'package:prep_manager/seguranca/armazenamento_seguro.dart';
import 'package:prep_manager/seguranca/kdf.dart';
import 'package:prep_manager/seguranca/totp.dart';

/// Resultado de uma tentativa de PIN ou de código 2FA.
class ResultadoTentativa {
  /// A tentativa estava certa.
  final bool correto;

  /// Se não for null, o app está em espera e só aceita nova tentativa depois disso.
  final Duration? espera;

  /// A tentativa chegou a ser avaliada? (false = já estava em espera, nem conferimos)
  final bool avaliada;

  /// Quantas tentativas erradas seguidas existem agora.
  final int falhas;

  const ResultadoTentativa({
    required this.correto,
    this.espera,
    this.avaliada = true,
    this.falhas = 0,
  });
}

/// Regras da trava do app: PIN, atraso progressivo, biometria e 2FA.
///
/// Não depende do Flutter. Tudo que é segredo vai para o [ArmazenamentoSeguro].
class TravaService {
  final ArmazenamentoSeguro _st;
  final DateTime Function() _agora;
  final int _iteracoesPin;
  final bool _isolado;

  TravaService(
    this._st, {
    DateTime Function()? agora,
    int iteracoesPin = 100000,
    bool isolado = true,
  })  : _agora = agora ?? DateTime.now,
        _iteracoesPin = iteracoesPin,
        _isolado = isolado;

  // Chaves no armazenamento seguro
  static const _kHash = 'pin_hash';
  static const _kSal = 'pin_sal';
  static const _kIter = 'pin_iter';
  static const _kBiometria = 'biometria_ativa';
  static const _kSegredo2fa = 'totp_segredo';
  static const _kUltimoPasso = 'totp_ultimo_passo';
  static const _kSegundos = 'trava_segundos';
  static const _prefixoPin = 'pin';
  static const _prefixo2fa = 'totp';

  static const int segundosPadrao = 10;

  /// Quanto esperar depois de [falhas] erros seguidos.
  static Duration esperaParaFalhas(int falhas) {
    if (falhas < 3) return Duration.zero;
    switch (falhas) {
      case 3:
        return const Duration(seconds: 30);
      case 4:
        return const Duration(minutes: 1);
      case 5:
        return const Duration(minutes: 5);
      case 6:
        return const Duration(minutes: 15);
      default:
        return const Duration(hours: 1);
    }
  }

  // ---------------------------------------------------------------- PIN

  static bool pinValido(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// PIN fácil demais: todos os dígitos iguais ou sequência (1234, 4321, 123456...).
  static bool pinFraco(String pin) {
    if (pin.isEmpty) return true;
    if (pin.split('').toSet().length == 1) return true;
    var sobe = true;
    var desce = true;
    for (var i = 1; i < pin.length; i++) {
      final d = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1);
      if (d != 1) sobe = false;
      if (d != -1) desce = false;
    }
    return sobe || desce;
  }

  Future<bool> get pinConfigurado async => (await _st.ler(_kHash)) != null;

  /// Define (ou troca) o PIN. Guarda só um hash com sal, nunca o PIN em si.
  Future<void> definirPin(String pin) async {
    if (!pinValido(pin)) {
      throw ArgumentError('O PIN deve ter de 4 a 6 dígitos.');
    }
    final r = Random.secure();
    final sal = List<int>.generate(16, (_) => r.nextInt(256));
    final hash = await derivarChave(pin, sal, _iteracoesPin, isolado: _isolado);

    await _st.gravar(_kSal, base64Encode(sal));
    await _st.gravar(_kHash, base64Encode(hash));
    await _st.gravar(_kIter, '$_iteracoesPin');
    await _zerarFalhas(_prefixoPin);
  }

  /// Confere o PIN, aplicando o atraso progressivo depois de erros seguidos.
  Future<ResultadoTentativa> verificarPin(String pin) async {
    final espera = await _esperaRestante(_prefixoPin);
    if (espera != null) {
      return ResultadoTentativa(
        correto: false,
        espera: espera,
        avaliada: false,
        falhas: await _falhas(_prefixoPin),
      );
    }

    final salTexto = await _st.ler(_kSal);
    final hashTexto = await _st.ler(_kHash);
    if (salTexto == null || hashTexto == null || !pinValido(pin)) {
      return _registrarFalha(_prefixoPin);
    }

    final iteracoes = int.tryParse(await _st.ler(_kIter) ?? '') ?? _iteracoesPin;
    final calculado =
        await derivarChave(pin, base64Decode(salTexto), iteracoes, isolado: _isolado);

    if (bytesIguais(calculado, base64Decode(hashTexto))) {
      await _zerarFalhas(_prefixoPin);
      return const ResultadoTentativa(correto: true);
    }
    return _registrarFalha(_prefixoPin);
  }

  /// Tempo que ainda falta de espera por causa de erros de PIN (null = livre).
  Future<Duration?> esperaPinRestante() => _esperaRestante(_prefixoPin);

  // ----------------------------------------------------------- Biometria

  Future<bool> get biometriaAtiva async => (await _st.ler(_kBiometria)) == '1';

  Future<void> definirBiometria(bool ativa) =>
      _st.gravar(_kBiometria, ativa ? '1' : '0');

  // ------------------------------------------------- Tempo para travar

  Future<int> segundosParaTravar() async =>
      int.tryParse(await _st.ler(_kSegundos) ?? '') ?? segundosPadrao;

  Future<void> definirSegundosParaTravar(int segundos) =>
      _st.gravar(_kSegundos, '${segundos < 0 ? 0 : segundos}');

  // ----------------------------------------------------------------- 2FA

  Future<bool> get doisFatoresAtivo async => (await _st.ler(_kSegredo2fa)) != null;

  /// Confere o código contra o [segredo] ainda não salvo e, se estiver certo,
  /// ativa o 2FA. Assim só ativamos depois de provar que o app autenticador funciona.
  Future<bool> ativarDoisFatores(String segredo, String codigo) async {
    final passo = Totp.verificar(segredo, codigo, agora: _agora());
    if (passo == null) return false;
    await _st.gravar(_kSegredo2fa, segredo);
    await _st.gravar(_kUltimoPasso, '$passo');
    await _zerarFalhas(_prefixo2fa);
    return true;
  }

  /// Confere um código 2FA (com atraso progressivo e sem aceitar o mesmo código duas vezes).
  Future<ResultadoTentativa> verificarDoisFatores(String codigo) async {
    final espera = await _esperaRestante(_prefixo2fa);
    if (espera != null) {
      return ResultadoTentativa(
        correto: false,
        espera: espera,
        avaliada: false,
        falhas: await _falhas(_prefixo2fa),
      );
    }

    final segredo = await _st.ler(_kSegredo2fa);
    if (segredo == null) return _registrarFalha(_prefixo2fa);

    final ultimo = int.tryParse(await _st.ler(_kUltimoPasso) ?? '');
    final passo = Totp.verificar(
      segredo,
      codigo,
      agora: _agora(),
      ultimoPassoUsado: ultimo,
    );

    if (passo == null) return _registrarFalha(_prefixo2fa);

    await _st.gravar(_kUltimoPasso, '$passo');
    await _zerarFalhas(_prefixo2fa);
    return const ResultadoTentativa(correto: true);
  }

  Future<Duration?> esperaDoisFatoresRestante() => _esperaRestante(_prefixo2fa);

  Future<void> desativarDoisFatores() async {
    await _st.apagar(_kSegredo2fa);
    await _st.apagar(_kUltimoPasso);
    await _zerarFalhas(_prefixo2fa);
  }

  // ------------------------------------------------- Atraso progressivo

  Future<int> _falhas(String prefixo) async =>
      int.tryParse(await _st.ler('${prefixo}_falhas') ?? '') ?? 0;

  Future<void> _zerarFalhas(String prefixo) async {
    await _st.apagar('${prefixo}_falhas');
    await _st.apagar('${prefixo}_bloqueio_ate');
  }

  Future<Duration?> _esperaRestante(String prefixo) async {
    final ate = int.tryParse(await _st.ler('${prefixo}_bloqueio_ate') ?? '');
    if (ate == null) return null;
    final restante = ate - _agora().millisecondsSinceEpoch;
    return restante > 0 ? Duration(milliseconds: restante) : null;
  }

  Future<ResultadoTentativa> _registrarFalha(String prefixo) async {
    final falhas = (await _falhas(prefixo)) + 1;
    await _st.gravar('${prefixo}_falhas', '$falhas');

    final espera = esperaParaFalhas(falhas);
    if (espera > Duration.zero) {
      final ate = _agora().millisecondsSinceEpoch + espera.inMilliseconds;
      await _st.gravar('${prefixo}_bloqueio_ate', '$ate');
      return ResultadoTentativa(correto: false, espera: espera, falhas: falhas);
    }
    return ResultadoTentativa(correto: false, falhas: falhas);
  }
}
