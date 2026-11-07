import 'package:flutter/material.dart';

/// As bolinhas que mostram quantos dígitos já foram digitados.
class PontosPin extends StatelessWidget {
  final int preenchidos;
  final int total;

  const PontosPin({super.key, required this.preenchidos, required this.total});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < preenchidos ? cor : null,
              border: Border.all(color: cor, width: 2),
            ),
          ),
      ],
    );
  }
}

/// Teclado numérico com bolinhas. Serve para PIN (de [minimo] a [maximo] dígitos)
/// e para códigos fixos (quando [minimo] == [maximo], envia sozinho no último dígito).
///
/// Depois de cada envio o campo é limpo, para uma nova tentativa.
class EntradaNumerica extends StatefulWidget {
  final int minimo;
  final int maximo;
  final bool habilitada;
  final ValueChanged<String> onConcluir;

  /// Botão opcional no canto inferior esquerdo (ex.: biometria).
  final Widget? botaoExtra;

  const EntradaNumerica({
    super.key,
    required this.minimo,
    required this.maximo,
    required this.onConcluir,
    this.habilitada = true,
    this.botaoExtra,
  });

  @override
  State<EntradaNumerica> createState() => _EntradaNumericaState();
}

class _EntradaNumericaState extends State<EntradaNumerica> {
  String _valor = '';

  void _digito(String d) {
    if (!widget.habilitada || _valor.length >= widget.maximo) return;
    setState(() => _valor += d);
    if (_valor.length == widget.maximo) _enviar();
  }

  void _apagar() {
    if (!widget.habilitada || _valor.isEmpty) return;
    setState(() => _valor = _valor.substring(0, _valor.length - 1));
  }

  void _enviar() {
    if (_valor.length < widget.minimo) return;
    final enviado = _valor;
    setState(() => _valor = '');
    widget.onConcluir(enviado);
  }

  @override
  Widget build(BuildContext context) {
    final variavel = widget.minimo < widget.maximo;

    Widget tecla(String texto) => _Tecla(
          onPressed: widget.habilitada ? () => _digito(texto) : null,
          filho: Text(texto, style: const TextStyle(fontSize: 28)),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PontosPin(preenchidos: _valor.length, total: widget.maximo),
        const SizedBox(height: 24),
        for (final linha in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in linha) tecla(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 84, height: 84, child: widget.botaoExtra),
            tecla('0'),
            _Tecla(
              onPressed: widget.habilitada ? _apagar : null,
              filho: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        if (variavel) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.habilitada && _valor.length >= widget.minimo
                ? _enviar
                : null,
            child: const Text('OK'),
          ),
        ],
      ],
    );
  }
}

class _Tecla extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget filho;

  const _Tecla({required this.onPressed, required this.filho});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextButton(
          style: TextButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: filho,
        ),
      ),
    );
  }
}
