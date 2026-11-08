import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Intensidade do desfoque. Com 0, não desfoca (bem mais leve: use em
  /// botões repetidos, como as teclas do PIN).
  final double desfoque;

  /// Quanto o vidro "cobre" (1 = normal). Use mais em painéis com muito
  /// texto, como formulários, para a leitura ficar mais fácil.
  final double intensidade;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Sombra suave em volta: destaca o botão quando ele está sobre outro vidro.
  final bool sombra;

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
    this.sombra = false,
  });

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final base = tom ?? Colors.white;

    // O vidro tingido precisa de mais cor para aparecer; o branco, de menos.
    final forte = ((tom != null ? 0.30 : (escuro ? 0.16 : 0.55)) * intensidade)
        .clamp(0.0, 1.0);
    final fraco = ((tom != null ? 0.12 : (escuro ? 0.05 : 0.35)) * intensidade)
        .clamp(0.0, 1.0);

    final superficie = DecoratedBox(
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
    );

    Widget vidro = ClipRRect(
      borderRadius: borderRadius,
      child: desfoque <= 0
          ? superficie
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: desfoque, sigmaY: desfoque),
              child: superficie,
            ),
    );
    if (sombra) {
      vidro = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: escuro ? 0.30 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: vidro,
      );
    }

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
///
/// Por padrão é tingido com a cor principal (ação principal). Com [secundario],
/// o vidro fica neutro (ações como "Voltar", "Agora não"). [tom] troca a cor
/// do tingimento (ex.: vermelho para ações perigosas).
class BotaoVidro extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool larguraTotal;
  final bool secundario;
  final Color? tom;

  const BotaoVidro({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
    this.larguraTotal = false,
    this.secundario = false,
    this.tom,
  });

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    // Botão principal: verde mais forte com texto branco (o preto sumia
    // sobre o vidro tingido). Secundário: vidro neutro com texto do tema.
    final principal = !secundario && tom == null;
    final corTexto = tom ?? (secundario ? cores.onSurface : Colors.white);

    final conteudo = Row(
      mainAxisSize: larguraTotal ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icone != null) ...[
          Icon(icone, color: corTexto),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, color: corTexto),
          ),
        ),
      ],
    );

    final botao = Vidro(
      tom: tom ?? (secundario ? null : cores.primary),
      intensidade: principal ? 3 : (secundario ? 1.4 : 1),
      borderRadius: BorderRadius.circular(28),
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: secundario ? 12 : 16,
        ),
        child: conteudo,
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child:
          larguraTotal ? SizedBox(width: double.infinity, child: botao) : botao,
    );
  }
}

/// Botão redondo de vidro (teclas do teclado de PIN, botão de digital etc.).
class BotaoVidroRedondo extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double tamanho;
  final double desfoque;
  final bool sombra;

  /// Dispara no instante em que o dedo encosta (como o teclado do celular),
  /// e não quando ele sobe. Assim nenhum toque rápido se perde, nem quando
  /// o dedo escorrega um pouco. Use nas teclas do PIN.
  final bool imediato;

  const BotaoVidroRedondo({
    super.key,
    required this.child,
    required this.onPressed,
    this.tamanho = 76,
    this.desfoque = 14,
    this.imediato = false,
    this.sombra = false,
  });

  @override
  Widget build(BuildContext context) {
    final acao = onPressed;
    final botao = Opacity(
      opacity: acao == null ? 0.5 : 1,
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: Vidro(
          intensidade: 1.4,
          desfoque: desfoque,
          sombra: sombra,
          borderRadius: BorderRadius.circular(tamanho / 2),
          // No modo imediato, o toque é tratado pelo Listener abaixo; o
          // onTap vazio só mantém o efeito visual do toque.
          onTap: acao == null ? null : (imediato ? () {} : acao),
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              child: IconTheme.merge(
                data: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurface),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (!imediato || acao == null) return botao;
    return Listener(
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        acao();
      },
      child: botao,
    );
  }
}

/// Painel de vidro para TEXTOS sobre a imagem de fundo (títulos e avisos das
/// telas de PIN, por exemplo). Mais opaco e mais desfocado que os botões,
/// para a leitura ficar boa também no modo claro.
///
/// Com [gradiente], o vidro vai de opaco no topo (títulos) a quase
/// transparente embaixo (teclado), deixando a imagem aparecer atrás dos números.
class PainelVidro extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool gradiente;

  const PainelVidro({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 16),
    this.gradiente = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!gradiente) {
      return Vidro(
        intensidade: 1.6,
        desfoque: 20,
        borderRadius: BorderRadius.circular(28),
        child: Padding(padding: padding, child: child),
      );
    }

    final escuro = Theme.of(context).brightness == Brightness.dark;
    final raio = BorderRadius.circular(28);
    // Opaco até ~30% da altura (títulos), depois vai sumindo até embaixo.
    final topo = escuro ? 0.26 : 0.88;
    final meio = escuro ? 0.14 : 0.55;
    final fim = escuro ? 0.03 : 0.10;
    final borda = escuro ? 0.22 : 0.65;

    return ClipRRect(
      borderRadius: raio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: raio,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.30, 0.60, 1],
              colors: [
                Colors.white.withValues(alpha: topo),
                Colors.white.withValues(alpha: topo),
                Colors.white.withValues(alpha: meio),
                Colors.white.withValues(alpha: fim),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: borda)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
