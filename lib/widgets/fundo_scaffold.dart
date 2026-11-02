import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/services/fundo_service.dart';

/// Igual ao Scaffold, mas com a imagem de fundo do app por trás da tela.
/// (cada tela leva o fundo junto, assim a troca de telas continua suave)
class FundoScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const FundoScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _FundoImagem(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar == null ? null : _BarraVidro(appBar!),
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

class _FundoImagem extends StatelessWidget {
  const _FundoImagem();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final corBase = tema.colorScheme.surface;
    final escuro = tema.brightness == Brightness.dark;

    // Redesenha na hora quando o usuário liga/desliga o fundo nos Ajustes
    return ValueListenableBuilder(
      valueListenable:
          Hive.box('settings').listenable(keys: [FundoService.chaveAtivo]),
      builder: (context, box, _) {
        // Modo escuro do celular -> imagens de DarkMode; claro -> LightMode
        final imagem =
            FundoService.ativo ? FundoService.imagemPara(escuro: escuro) : null;

        // Carrega a imagem já no tamanho da tela (poupa memória)
        final largura = (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: corBase),
            if (imagem != null) ...[
              Image.asset(
                imagem,
                fit: BoxFit.cover,
                cacheWidth: largura,
                gaplessPlayback: true,
                // Se a imagem estiver com problema, fica só a cor de fundo
                errorBuilder: (context, erro, pilha) => const SizedBox.shrink(),
              ),
              // Véu por cima da imagem para o texto continuar legível:
              // escuro no modo escuro, claro no modo claro
              ColoredBox(
                color: escuro
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Dá à barra superior o mesmo efeito de vidro, para o título ficar legível
/// em cima de qualquer imagem.
class _BarraVidro extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget barra;

  const _BarraVidro(this.barra);

  @override
  Size get preferredSize => barra.preferredSize;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(
          color: escuro
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.50),
          child: barra,
        ),
      ),
    );
  }
}
