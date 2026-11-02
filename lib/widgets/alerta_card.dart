import 'package:flutter/material.dart';
import 'package:prep_manager/widgets/vidro.dart';

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
    return Vidro(
      tom: cor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: cor),
        title: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
