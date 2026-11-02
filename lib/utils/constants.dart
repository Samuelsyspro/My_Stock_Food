import 'package:flutter/material.dart';
import 'package:prep_manager/services/categoria_service.dart';

class CategoriasApp {
  /// Nomes de todas as categorias: as do app + as criadas pelo usuário.
  /// (muda quando o usuário cria ou remove uma categoria)
  static List<String> get nomes => CategoriaService().todosOsNomes();

  // Ícone e cor das categorias que já vêm com o app
  static const Map<String, IconData> icones = {
    'Bebidas': Icons.liquor,
    'Alimentos': Icons.restaurant,
    'Combustível': Icons.local_gas_station,
    'Médico': Icons.medical_services,
    'Higiene': Icons.soap,
    'Ferramentas': Icons.build,
    'Outros': Icons.inventory_2,
  };

  static const Map<String, Color> cores = {
    'Bebidas': Color(0xFF0288D1),
    'Alimentos': Color(0xFF388E3C),
    'Combustível': Color(0xFFF57C00),
    'Médico': Color(0xFFD32F2F),
    'Higiene': Color(0xFF7B1FA2),
    'Ferramentas': Color(0xFF455A64),
    'Outros': Color(0xFF5D4037),
  };

  /// Ícones que o usuário pode escolher ao criar uma categoria.
  /// A chave (texto) é o que fica salvo; o desenho vem daqui. Os ícones ficam
  /// numa lista fixa de propósito: assim o app final continua leve e seguro.
  static const Map<String, IconData> catalogoIcones = {
    'categoria': Icons.category,
    'cesta': Icons.shopping_basket,
    'carrinho': Icons.shopping_cart,
    'comida': Icons.restaurant,
    'cafe': Icons.local_cafe,
    'bolo': Icons.cake,
    'sorvete': Icons.icecream,
    'padaria': Icons.bakery_dining,
    'pizza': Icons.local_pizza,
    'peixe': Icons.set_meal,
    'ovo': Icons.egg,
    'folha': Icons.eco,
    'spa': Icons.spa,
    'pet': Icons.pets,
    'bebe': Icons.child_care,
    'roupa': Icons.checkroom,
    'limpeza': Icons.cleaning_services,
    'casa': Icons.home,
    'cozinha': Icons.kitchen,
    'sofa': Icons.chair,
    'cama': Icons.bed,
    'tv': Icons.tv,
    'computador': Icons.computer,
    'celular': Icons.phone_android,
    'ferramenta': Icons.handyman,
    'eletrica': Icons.electrical_services,
    'lampada': Icons.lightbulb,
    'carro': Icons.directions_car,
    'moto': Icons.two_wheeler,
    'remedio': Icons.medication,
    'vacina': Icons.vaccines,
    'esporte': Icons.fitness_center,
    'bola': Icons.sports_soccer,
    'livro': Icons.menu_book,
    'escola': Icons.school,
    'trabalho': Icons.work,
    'brinquedo': Icons.toys,
    'arte': Icons.brush,
    'mala': Icons.luggage,
    'floresta': Icons.forest,
    'agua': Icons.water_drop,
    'frio': Icons.ac_unit,
    'fogo': Icons.local_fire_department,
    'estrela': Icons.star,
    'coracao': Icons.favorite,
    'caixa': Icons.inventory_2,
  };

  /// Ícone da categoria (usa um genérico se não reconhecer o nome).
  static IconData iconeDe(String categoria) {
    final padrao = icones[categoria];
    if (padrao != null) return padrao;

    final criada = CategoriaService().buscar(categoria);
    return catalogoIcones[criada?.icone] ?? Icons.category;
  }

  /// Cor da categoria (usa a de "Outros" se não reconhecer o nome).
  static Color corDe(String categoria) {
    final padrao = cores[categoria];
    if (padrao != null) return padrao;

    final criada = CategoriaService().buscar(categoria);
    return criada != null ? Color(criada.cor) : const Color(0xFF5D4037);
  }
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
