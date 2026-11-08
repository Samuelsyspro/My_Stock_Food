import 'package:flutter/material.dart';

/// Superfície comum para o CONTEÚDO do app (cartões, listas, painéis).
///
/// Cor quase sólida, sem desfoque: o texto continua legível sobre a imagem de
/// fundo. O efeito de vidro (Vidro) fica só nos botões e nas barras.
class Superficie extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;

  /// Cor opcional para tingir a superfície (ex.: vermelho nos alertas).
  final Color? tom;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Superficie({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.margin,
    this.tom,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final escuro = tema.brightness == Brightness.dark;

    final base = escuro
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.07),
            tema.colorScheme.surface,
          )
        : Colors.white;
    final fundo = tom == null
        ? base
        : Color.alphaBlend(tom!.withValues(alpha: 0.2), base);

    final conteudo = Material(
      color: fundo.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );

    return margin == null ? conteudo : Padding(padding: margin!, child: conteudo);
  }
}
