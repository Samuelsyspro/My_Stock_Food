import 'package:flutter/material.dart';

class CategoriasApp {
  static const List<String> nomes = [
    'Bebidas',
    'Alimentos',
    'Combustível',
    'Médico',
    'Higiene',
    'Ferramentas',
    'Outros',
  ];

  // Ícone de cada categoria
  static const Map<String, IconData> icones = {
    'Bebidas': Icons.liquor,
    'Alimentos': Icons.restaurant,
    'Combustível': Icons.local_gas_station,
    'Médico': Icons.medical_services,
    'Higiene': Icons.soap,
    'Ferramentas': Icons.build,
    'Outros': Icons.inventory_2,
  };

  // Cor de cada categoria
  static const Map<String, Color> cores = {
    'Bebidas': Color(0xFF0288D1),
    'Alimentos': Color(0xFF388E3C),
    'Combustível': Color(0xFFF57C00),
    'Médico': Color(0xFFD32F2F),
    'Higiene': Color(0xFF7B1FA2),
    'Ferramentas': Color(0xFF455A64),
    'Outros': Color(0xFF5D4037),
  };

  /// Ícone da categoria (usa o de "Outros" se não reconhecer o nome)
  static IconData iconeDe(String categoria) =>
      icones[categoria] ?? Icons.inventory_2;

  /// Cor da categoria (usa a de "Outros" se não reconhecer o nome)
  static Color corDe(String categoria) =>
      cores[categoria] ?? const Color(0xFF5D4037);
}

class UnidadesApp {
  static const List<String> nomes = [
    'un',
    'kg',
    'g',
    'L',
    'ml',
    'cx',
  ];
}
