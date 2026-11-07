import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prep_manager/seguranca/controle_trava.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/ui/teclado_pin.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';

/// Pede para o usuário provar quem é antes de uma ação sensível
/// (gerar ou restaurar backup, trocar o PIN, desativar o 2FA).
///
/// Se o 2FA estiver ativo, pede o código do autenticador; senão, o PIN.
/// Com [permitirEscolha] (e 2FA ativo), o usuário pode escolher entre os dois.
/// Devolve true se a identidade foi confirmada.
Future<bool> confirmarIdentidade(
  BuildContext context, {
  required String motivo,
  bool permitirEscolha = false,
}) async {
  final tem2fa = await Seguranca.instancia.trava.doisFatoresAtivo;
  if (!context.mounted) return false;

  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ConfirmarIdentidadeScreen(
        motivo: motivo,
        usar2fa: tem2fa,
        permitirEscolha: permitirEscolha && tem2fa,
      ),
    ),
  );
  return ok == true;
}

class ConfirmarIdentidadeScreen extends StatefulWidget {
  final String motivo;
  final bool usar2fa;
  final bool permitirEscolha;

  const ConfirmarIdentidadeScreen({
    super.key,
    required this.motivo,
    required this.usar2fa,
    required this.permitirEscolha,
  });

  @override
  State<ConfirmarIdentidadeScreen> createState() =>
      _ConfirmarIdentidadeScreenState();
}

class _ConfirmarIdentidadeScreenState extends State<ConfirmarIdentidadeScreen> {
  final _trava = Seguranca.instancia.trava;

  late bool _usar2fa = widget.usar2fa;
  bool _verificando = false;
  String? _mensagem;
  DateTime? _esperaAte;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _atualizarEspera();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _atualizarEspera() async {
    final espera = _usar2fa
        ? await _trava.esperaDoisFatoresRestante()
        : await _trava.esperaPinRestante();
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

  Future<void> _verificar(String valor) async {
    setState(() => _verificando = true);
    final r = _usar2fa
        ? await _trava.verificarDoisFatores(valor)
        : await _trava.verificarPin(valor);
    if (!mounted) return;

    if (r.correto) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _verificando = false;
      _mensagem = r.espera != null
          ? 'Muitas tentativas erradas.'
          : (_usar2fa ? 'Código incorreto.' : 'PIN incorreto.');
    });
    if (r.espera != null) await _atualizarEspera();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final restante = _esperaAte?.difference(DateTime.now());

    return FundoScaffold(
      appBar: AppBar(title: const Text('Confirmar que é você')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _usar2fa ? Icons.shield_outlined : Icons.lock_outline,
                  size: 48,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _usar2fa ? 'Código do autenticador' : 'Digite o seu PIN',
                  style: tema.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(widget.motivo, textAlign: TextAlign.center),
                if (restante != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tente de novo em ${formatarEspera(restante)}',
                      style: TextStyle(
                        color: tema.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 44,
                  child: _mensagem == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _mensagem!,
                            style: TextStyle(color: tema.colorScheme.error),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                EntradaNumerica(
                  key: ValueKey(_usar2fa),
                  minimo: _usar2fa ? 6 : 4,
                  maximo: 6,
                  habilitada: !_verificando && _esperaAte == null,
                  onConcluir: _verificar,
                ),
                if (widget.permitirEscolha)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _usar2fa = !_usar2fa;
                        _mensagem = null;
                      });
                      _atualizarEspera();
                    },
                    child: Text(_usar2fa
                        ? 'Usar o PIN'
                        : 'Usar o código do autenticador'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
