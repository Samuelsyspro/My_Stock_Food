import 'package:flutter/material.dart';

/// Tipo do aviso: muda o ícone, a cor e o título padrão do popup.
enum TipoAviso { sucesso, erro, info }

/// Mostra uma mensagem de aviso em um popup (no lugar da barra de baixo).
///
/// Use sempre esta função para avisos do app, para todos ficarem iguais.
/// Termina quando a pessoa toca em "OK".
Future<void> mostrarAviso(
  BuildContext context,
  String mensagem, {
  TipoAviso tipo = TipoAviso.info,
  String? titulo,
}) {
  final cores = Theme.of(context).colorScheme;
  final (IconData icone, Color cor, String tituloPadrao) = switch (tipo) {
    TipoAviso.sucesso => (Icons.check_circle_outline, const Color(0xFF2E7D32), 'Pronto'),
    TipoAviso.erro => (Icons.error_outline, cores.error, 'Algo deu errado'),
    TipoAviso.info => (Icons.info_outline, cores.primary, 'Aviso'),
  };

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icone, color: cor, size: 40),
      title: Text(titulo ?? tituloPadrao, textAlign: TextAlign.center),
      content: Text(mensagem, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
