import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prep_manager/seguranca/controle_trava.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/ui/fluxo_criar_pin.dart';
import 'package:prep_manager/seguranca/ui/teclado_pin.dart';

enum _Modo {
  carregando,
  pin,
  criarPin,
  recuperar,
  codigo2fa,
  escolhaPosRecuperacao,
  novoPin,
  ofertaBiometria,
}

/// Tela que cobre o app inteiro enquanto ele está travado.
///
/// Usa só o teclado numérico da própria tela (sem campos de texto), então
/// funciona mesmo estando acima do navegador do app.
class TelaBloqueio extends StatefulWidget {
  /// Chamado quando o usuário liberou o app. [abrirAjustes] = true leva
  /// direto para os Ajustes (para trocar o PIN usando o 2FA).
  final void Function({bool abrirAjustes}) onDesbloqueado;

  const TelaBloqueio({super.key, required this.onDesbloqueado});

  @override
  State<TelaBloqueio> createState() => _TelaBloqueioState();
}

class _TelaBloqueioState extends State<TelaBloqueio> {
  final _trava = Seguranca.instancia.trava;
  final _bio = Seguranca.instancia.biometria;

  _Modo _modo = _Modo.carregando;
  bool _biometriaAtiva = false;
  bool _tem2fa = false;
  bool _verificando = false;
  String? _mensagem;
  DateTime? _esperaAte;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final configurado = await _trava.pinConfigurado;
    _biometriaAtiva = await _trava.biometriaAtiva;
    _tem2fa = await _trava.doisFatoresAtivo;
    if (!mounted) return;

    setState(() => _modo = configurado ? _Modo.pin : _Modo.criarPin);
    if (!configurado) return;

    await _atualizarEspera();
    if (_biometriaAtiva && _esperaAte == null) _pedirBiometria();
  }

  // ------------------------------------------------------------ espera

  Future<void> _atualizarEspera() async {
    final espera = await _trava.esperaPinRestante();
    if (!mounted) return;
    setState(() => _esperaAte = espera == null ? null : DateTime.now().add(espera));
    _relogio?.cancel();
    if (_esperaAte == null) return;

    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_esperaAte!)) {
        _relogio?.cancel();
        setState(() {
          _esperaAte = null;
          _mensagem = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Duration? get _restante =>
      _esperaAte?.difference(DateTime.now());

  // --------------------------------------------------------------- PIN

  Future<void> _aoDigitarPin(String pin) async {
    setState(() => _verificando = true);
    final r = await _trava.verificarPin(pin);
    if (!mounted) return;

    if (r.correto) {
      widget.onDesbloqueado();
      return;
    }
    setState(() {
      _verificando = false;
      _mensagem = r.espera != null
          ? 'Muitas tentativas erradas.'
          : 'PIN incorreto.';
    });
    if (r.espera != null) await _atualizarEspera();
  }

  Future<void> _pedirBiometria() async {
    final ok = await _bio.autenticarBiometria('Confirme que é você para abrir o app');
    if (ok && mounted) widget.onDesbloqueado();
  }

  // -------------------------------------------------------- recuperação

  Future<void> _recuperarComCelular() async {
    if (!await _bio.bloqueioDoCelularDisponivel) {
      if (!mounted) return;
      setState(() => _mensagem =
          'Este celular não tem bloqueio de tela configurado. Use o código do autenticador.');
      return;
    }
    final ok = await _bio.autenticarComBloqueioDoCelular(
      'Confirme que é você para redefinir o PIN',
    );
    if (!mounted) return;
    setState(() {
      if (ok) {
        _mensagem = null;
        _modo = _Modo.escolhaPosRecuperacao;
      } else {
        _mensagem = 'Não foi possível confirmar pelo bloqueio do celular.';
      }
    });
  }

  Future<void> _aoDigitarCodigo2fa(String codigo) async {
    setState(() => _verificando = true);
    final r = await _trava.verificarDoisFatores(codigo);
    if (!mounted) return;

    if (r.correto) {
      setState(() {
        _verificando = false;
        _mensagem = null;
        _modo = _Modo.novoPin;
      });
      return;
    }
    setState(() {
      _verificando = false;
      _mensagem = r.espera != null
          ? 'Muitas tentativas erradas. Aguarde ${formatarEspera(r.espera!)}.'
          : 'Código incorreto.';
    });
  }

  Future<void> _ativarBiometria() async {
    final ok = await _bio.autenticarBiometria('Confirme para ativar a biometria');
    if (ok) await _trava.definirBiometria(true);
    if (mounted) widget.onDesbloqueado();
  }

  void _irPara(_Modo modo) => setState(() {
        _modo = modo;
        _mensagem = null;
      });

  // ------------------------------------------------------------- telas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _conteudo(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final tema = Theme.of(context);

    Widget aviso() => SizedBox(
          height: 48,
          child: _mensagem == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _mensagem!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
        );

    switch (_modo) {
      case _Modo.carregando:
        return const Center(child: CircularProgressIndicator());

      case _Modo.pin:
        final restante = _restante;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('App protegido', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Digite o seu PIN para continuar.'),
            if (restante != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tente de novo em ${formatarEspera(restante)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tema.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            aviso(),
            const SizedBox(height: 8),
            EntradaNumerica(
              minimo: 4,
              maximo: 6,
              habilitada: !_verificando && _esperaAte == null,
              onConcluir: _aoDigitarPin,
              botaoExtra: _biometriaAtiva
                  ? IconButton(
                      icon: const Icon(Icons.fingerprint, size: 36),
                      onPressed: _esperaAte == null ? _pedirBiometria : null,
                    )
                  : null,
            ),
            TextButton(
              onPressed: () => _irPara(_Modo.recuperar),
              child: const Text('Esqueci o PIN'),
            ),
          ],
        );

      case _Modo.criarPin:
        return FluxoCriarPin(
          titulo: 'Proteja o app com um PIN',
          onConcluido: (pin) async {
            await _trava.definirPin(pin);
            final podeBiometria = await _bio.biometriaDisponivel;
            if (!mounted) return;
            if (podeBiometria) {
              _irPara(_Modo.ofertaBiometria);
            } else {
              widget.onDesbloqueado();
            }
          },
        );

      case _Modo.ofertaBiometria:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, size: 64, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Abrir com digital ou rosto?',
                textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Fica mais rápido. O PIN continua funcionando sempre que você quiser.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _ativarBiometria,
              child: const Text('Ativar'),
            ),
            TextButton(
              onPressed: () => widget.onDesbloqueado(),
              child: const Text('Agora não'),
            ),
          ],
        );

      case _Modo.recuperar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Esqueci o PIN', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Confirme que é você. Os seus dados continuam guardados.',
              textAlign: TextAlign.center,
            ),
            aviso(),
            FilledButton.icon(
              onPressed: _recuperarComCelular,
              icon: const Icon(Icons.phone_android),
              label: const Text('Usar o bloqueio do celular'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _tem2fa ? () => _irPara(_Modo.codigo2fa) : null,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Usar o código do autenticador (2FA)'),
            ),
            if (!_tem2fa)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'O 2FA ainda não foi ativado neste app.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            TextButton(
              onPressed: () => _irPara(_Modo.pin),
              child: const Text('Voltar'),
            ),
          ],
        );

      case _Modo.codigo2fa:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Código do autenticador', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Digite o código de 6 dígitos que aparece no seu app autenticador.',
              textAlign: TextAlign.center,
            ),
            aviso(),
            const SizedBox(height: 8),
            EntradaNumerica(
              minimo: 6,
              maximo: 6,
              habilitada: !_verificando,
              onConcluir: _aoDigitarCodigo2fa,
            ),
            TextButton(
              onPressed: () => _irPara(_Modo.recuperar),
              child: const Text('Voltar'),
            ),
          ],
        );

      case _Modo.escolhaPosRecuperacao:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Identidade confirmada', style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('O que você quer fazer agora?', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _irPara(_Modo.novoPin),
              child: const Text('Criar um novo PIN agora'),
            ),
            if (_tem2fa) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => widget.onDesbloqueado(abrirAjustes: true),
                child: const Text('Abrir os Ajustes (trocar o PIN com o 2FA)'),
              ),
            ],
          ],
        );

      case _Modo.novoPin:
        return FluxoCriarPin(
          titulo: 'Crie um novo PIN',
          onConcluido: (pin) async {
            await _trava.definirPin(pin);
            if (mounted) widget.onDesbloqueado();
          },
        );
    }
  }
}
