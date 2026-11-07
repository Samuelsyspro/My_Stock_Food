import 'package:flutter/material.dart';
import 'package:prep_manager/widgets/superficie.dart';

/// Cartão de categoria da tela da Dispensa.
class CategoriaCard extends StatelessWidget {
  final String nome;
  final IconData icone;
  final Color cor;
  final int quantidade;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // só nas categorias criadas pelo usuário

  const CategoriaCard({
    super.key,
    required this.nome,
    required this.icone,
    required this.cor,
    required this.quantidade,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Superficie(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 32, color: cor),
            const SizedBox(height: 8),
            Text(
              nome,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            Text(
              '$quantidade item(ns)',
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
