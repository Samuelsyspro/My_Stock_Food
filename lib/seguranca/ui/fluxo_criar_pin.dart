import 'package:flutter/material.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/trava_service.dart';
import 'package:prep_manager/seguranca/ui/teclado_pin.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';

/// Pede um PIN de 4 a 6 dígitos duas vezes (digitar e confirmar).
/// Quando os dois conferem, chama [onConcluido] com o PIN.
class FluxoCriarPin extends StatefulWidget {
  final String titulo;
  final Future<void> Function(String pin) onConcluido;

  /// Se informado, mostra o botão "Voltar" (desistir de trocar o PIN).
  final VoidCallback? onVoltar;

  const FluxoCriarPin({
    super.key,
    required this.titulo,
    required this.onConcluido,
    this.onVoltar,
  });

  @override
  State<FluxoCriarPin> createState() => _FluxoCriarPinState();
}

class _FluxoCriarPinState extends State<FluxoCriarPin> {
  String? _primeiro;
  String? _erro;
  bool _salvando = false;

  Future<void> _recebido(String pin) async {
    if (_primeiro == null) {
      if (TravaService.pinFraco(pin)) {
        setState(() => _erro =
            'Esse PIN é fácil de adivinhar (como 1234 ou 1111). Escolha outro.');
        return;
      }
      setState(() {
        _primeiro = pin;
        _erro = null;
      });
      return;
    }

    if (pin != _primeiro) {
      setState(() {
        _erro = 'Os dois PINs são diferentes. Comece de novo.';
        _primeiro = null;
      });
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.onConcluido(pin);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível salvar o PIN. Tente de novo.';
        _salvando = false;
        _primeiro = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vidro atrás dos textos: legível sobre a imagem, também no modo claro.
        PainelVidro(
          gradiente: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: tema.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _primeiro == null
                    ? 'Escolha um PIN de 4 a 6 dígitos.'
                    : 'Digite o mesmo PIN de novo para confirmar.',
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: 44,
                child: _erro == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tema.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              EntradaNumerica(
                minimo: 4,
                maximo: 6,
                habilitada: !_salvando,
                onConcluir: _recebido,
              ),
            ],
          ),
        ),
        if (_primeiro != null || widget.onVoltar != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onVoltar != null)
                Flexible(
                  child: BotaoVidro(
                    texto: 'Voltar',
                    icone: Icons.arrow_back,
                    secundario: true,
                    onPressed: _salvando ? null : widget.onVoltar,
                  ),
                ),
              if (_primeiro != null && widget.onVoltar != null)
                const SizedBox(width: 12),
              if (_primeiro != null)
                Flexible(
                  child: BotaoVidro(
                    texto: 'Começar de novo',
                    icone: Icons.refresh,
                    secundario: true,
                    onPressed: _salvando
                        ? null
                        : () => setState(() {
                              _primeiro = null;
                              _erro = null;
                            }),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Tela para trocar o PIN (aberta pelos Ajustes, depois de confirmar a identidade).
/// Devolve true ao fechar se o PIN foi alterado.
class NovoPinScreen extends StatelessWidget {
  const NovoPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FundoScaffold(
      appBar: AppBar(title: const Text('Novo PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FluxoCriarPin(
              titulo: 'Crie o novo PIN',
              onConcluido: (pin) async {
                await Seguranca.instancia.trava.definirPin(pin);
                if (context.mounted) Navigator.pop(context, true);
              },
            ),
          ),
        ),
      ),
    );
  }
}
