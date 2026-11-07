import 'dart:ui';

import 'package:flutter/material.dart';

/// Superfície de "vidro" (estilo Liquid Glass): translúcida, desfoca a imagem
/// que está por trás e tem uma borda clara nas pontas.
///
/// Uso restrito: BOTÕES e BARRAS. Para cartões, listas e painéis use
/// [Superficie] (widgets/superficie.dart), que é mais fácil de ler.
class Vidro extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;

  /// Cor opcional para tingir o vidro (ex.: vermelho nos alertas).
  final Color? tom;

  /// Intensidade do desfoque.
  final double desfoque;

  /// Quanto o vidro "cobre" (1 = normal). Use mais em painéis com muito
  /// texto, como formulários, para a leitura ficar mais fácil.
  final double intensidade;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Vidro({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.margin,
    this.tom,
    this.desfoque = 14,
    this.intensidade = 1,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final base = tom ?? Colors.white;

    // O vidro tingido precisa de mais cor para aparecer; o branco, de menos.
    final forte =
        ((tom != null ? 0.30 : (escuro ? 0.16 : 0.55)) * intensidade).clamp(0.0, 1.0);
    final fraco =
        ((tom != null ? 0.12 : (escuro ? 0.05 : 0.35)) * intensidade).clamp(0.0, 1.0);

    final vidro = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: desfoque, sigmaY: desfoque),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: forte),
                base.withValues(alpha: fraco),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: escuro ? 0.22 : 0.65),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: borderRadius,
              child: child,
            ),
          ),
        ),
      ),
    );

    return margin == null ? vidro : Padding(padding: margin!, child: vidro);
  }
}

/// Botão flutuante de vidro (no lugar do FloatingActionButton).
class FabVidro extends StatelessWidget {
  final IconData icone;
  final String? texto;
  final VoidCallback onPressed;

  const FabVidro({
    super.key,
    required this.icone,
    required this.onPressed,
    this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Vidro(
      tom: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(28),
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: texto != null ? 20 : 18,
          vertical: 16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone),
            if (texto != null) ...[
              const SizedBox(width: 8),
              Text(texto!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botão de vidro com texto (e ícone opcional). Com [larguraTotal], ocupa a largura toda.
class BotaoVidro extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool larguraTotal;

  const BotaoVidro({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
    this.larguraTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final conteudo = Row(
      mainAxisSize: larguraTotal ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icone != null) ...[
          Icon(icone),
          const SizedBox(width: 8),
        ],
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );

    final botao = Vidro(
      tom: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(28),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: conteudo,
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: larguraTotal ? SizedBox(width: double.infinity, child: botao) : botao,
    );
  }
}
