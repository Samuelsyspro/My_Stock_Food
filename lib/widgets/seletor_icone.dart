import 'package:flutter/material.dart';

/// Grade de ícones para escolher o ícone de uma categoria.
class SeletorIcone extends StatelessWidget {
  final Map<String, IconData> icones;
  final String selecionado;
  final ValueChanged<String> onSelecionar;

  const SeletorIcone({
    super.key,
    required this.icones,
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entrada in icones.entries)
          InkWell(
            onTap: () => onSelecionar(entrada.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: entrada.key == selecionado
                    ? cor.withValues(alpha: 0.25)
                    : null,
                border: Border.all(
                  color: entrada.key == selecionado ? cor : Colors.grey.shade700,
                  width: entrada.key == selecionado ? 2 : 1,
                ),
              ),
              child: Icon(
                entrada.value,
                color: entrada.key == selecionado ? cor : null,
              ),
            ),
          ),
      ],
    );
  }
}
