import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';
import 'package:prep_manager/seguranca/controle_trava.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/ui/fluxo_criar_pin.dart';
import 'package:prep_manager/seguranca/ui/teclado_pin.dart';

enum _Modo {
  carregando,
  biometria,
  pin,
  criarPin,
  recuperar,
  codigo2fa,
  novoPin,
  ofertaBiometria,
}

/// Tela que cobre o app inteiro enquanto ele está travado.
///
/// Usa só o teclado numérico da própria tela (sem campos de texto), então
/// funciona mesmo estando acima do navegador do app.
class TelaBloqueio extends StatefulWidget {
  /// Chamado quando o usuário liberou o app.
  final VoidCallback onDesbloqueado;

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

    if (!configurado) {
      setState(() => _modo = _Modo.criarPin);
      return;
    }

    await _atualizarEspera();
    if (!mounted) return;

    // Com a biometria ativa (e sem espera por tentativas erradas), abre direto
    // a digital/rosto, sem o teclado de PIN atrás. O PIN fica como opção.
    if (_biometriaAtiva && _esperaAte == null) {
      setState(() => _modo = _Modo.biometria);
      _pedirBiometria();
    } else {
      setState(() => _modo = _Modo.pin);
    }
  }

  // ------------------------------------------------------------ espera

  Future<void> _atualizarEspera() async {
    final espera = await _trava.esperaPinRestante();
    if (!mounted) return;
    setState(
        () => _esperaAte = espera == null ? null : DateTime.now().add(espera));
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

  Duration? get _restante => _esperaAte?.difference(DateTime.now());

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
      _mensagem =
          r.espera != null ? 'Muitas tentativas erradas.' : 'PIN incorreto.';
    });
    if (r.espera != null) await _atualizarEspera();
  }

  /// Mostra a tela da biometria (sem o teclado de PIN) e pede a digital/rosto.
  /// Se a pessoa cancelar ou errar, continua nessa tela, com as opções de
  /// tentar de novo ou usar o PIN.
  Future<void> _pedirBiometria() async {
    if (_verificando) return;
    setState(() {
      _modo = _Modo.biometria;
      _mensagem = null;
      _verificando = true;
    });
    final ok =
        await _bio.autenticarBiometria('Confirme que é você para abrir o app');
    if (!mounted) return;
    if (ok) {
      widget.onDesbloqueado();
      return;
    }
    setState(() {
      _verificando = false;
      _mensagem = 'Use a biometria ou digite o PIN para continuar.';
    });
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
        // Identidade confirmada: vai direto criar o novo PIN.
        _modo = _Modo.novoPin;
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
    final ok =
        await _bio.autenticarBiometria('Confirme para ativar a biometria');
    if (ok) await _trava.definirBiometria(true);
    if (mounted) widget.onDesbloqueado();
  }

  /// Desistiu de trocar o PIN: volta para a tela de desbloqueio
  /// (a da digital, se estiver ativa; senão, a do PIN). Não abre a digital
  /// sozinho: a pessoa escolhe no botão.
  void _voltarAoDesbloqueio() => _irPara(
      _biometriaAtiva && _esperaAte == null ? _Modo.biometria : _Modo.pin);

  void _irPara(_Modo modo) => setState(() {
        _modo = modo;
        _mensagem = null;
      });

  // ------------------------------------------------------------- telas

  @override
  Widget build(BuildContext context) {
    // Mesmo fundo das outras telas: imagem sorteada (modo claro ou escuro).
    return FundoScaffold(
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

    // Painel de vidro atrás do conteúdo, para o texto ficar legível
    // sobre qualquer imagem de fundo (principalmente no modo claro).
    Widget painel(Widget filho) => PainelVidro(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: filho,
        );

    switch (_modo) {
      case _Modo.carregando:
        return const Center(child: CircularProgressIndicator());

      case _Modo.biometria:
        return painel(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint,
                  size: 72, color: tema.colorScheme.primary),
              const SizedBox(height: 12),
              Text('App protegido',
                  style: tema.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Autentique-se para usar o app.',
                textAlign: TextAlign.center,
              ),
              aviso(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BotaoVidro(
                      texto: 'Digital',
                      icone: Icons.fingerprint,
                      larguraTotal: true,
                      onPressed: _verificando ? null : _pedirBiometria,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoVidro(
                      texto: 'PIN',
                      icone: Icons.dialpad,
                      secundario: true,
                      larguraTotal: true,
                      onPressed: _verificando ? null : () => _irPara(_Modo.pin),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case _Modo.pin:
        final restante = _restante;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PainelVidro(
              gradiente: true,
              child: Column(
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
                        ? Center(
                            child: BotaoVidroRedondo(
                              onPressed:
                                  _esperaAte == null ? _pedirBiometria : null,
                              // Igual às teclas do PIN
                              desfoque: 0,
                              sombra: true,
                              child: const Icon(Icons.fingerprint, size: 36),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BotaoVidro(
              texto: 'Esqueci o PIN',
              secundario: true,
              onPressed: () => _irPara(_Modo.recuperar),
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
        return painel(Column(
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
            BotaoVidro(
              texto: 'Ativar',
              icone: Icons.fingerprint,
              onPressed: _ativarBiometria,
            ),
            const SizedBox(height: 12),
            BotaoVidro(
              texto: 'Agora não',
              secundario: true,
              onPressed: () => widget.onDesbloqueado(),
            ),
          ],
        ));

      case _Modo.recuperar:
        return painel(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline,
                  size: 56, color: tema.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Esqueceu o PIN?',
                  style: tema.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Selecione uma das opções abaixo para recuperar o acesso ao app.',
                textAlign: TextAlign.center,
              ),
              aviso(),
              const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BotaoVidro(
                        texto: 'Desbloqueio do celular',
                        icone: Icons.phone_android,
                        larguraTotal: true,
                        onPressed: _recuperarComCelular,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BotaoVidro(
                        texto: 'Código 2FA',
                        icone: Icons.shield_outlined,
                        secundario: true,
                        larguraTotal: true,
                        onPressed:
                            _tem2fa ? () => _irPara(_Modo.codigo2fa) : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_tem2fa)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'O 2FA ainda não foi ativado neste app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              BotaoVidro(
                texto: 'Voltar',
                icone: Icons.arrow_back,
                secundario: true,
                larguraTotal: true,
                onPressed: () => _irPara(_Modo.pin),
              ),
            ],
          ),
        );

      case _Modo.codigo2fa:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PainelVidro(
              gradiente: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 48, color: tema.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Código do autenticador',
                      style: tema.textTheme.titleLarge),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            BotaoVidro(
              texto: 'Voltar',
              icone: Icons.arrow_back,
              secundario: true,
              onPressed: () => _irPara(_Modo.recuperar),
            ),
          ],
        );

      case _Modo.novoPin:
        return FluxoCriarPin(
          titulo: 'Crie um novo PIN',
          onVoltar: _voltarAoDesbloqueio,
          onConcluido: (pin) async {
            await _trava.definirPin(pin);
            if (mounted) widget.onDesbloqueado();
          },
        );
    }
  }
}
