import 'package:flutter/material.dart';

/// Cartão de alerta (itens vencidos / que vencem em breve).
class AlertaCard extends StatelessWidget {
  final String titulo;
  final Color cor;
  final VoidCallback onTap;

  const AlertaCard({
    super.key,
    required this.titulo,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cor.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: cor),
        title: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
