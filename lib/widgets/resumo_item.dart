import 'package:flutter/material.dart';

/// Número do "Resumo do Estoque" (clicável).
class ResumoItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final VoidCallback onTap;

  const ResumoItem({
    super.key,
    required this.label,
    required this.valor,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
