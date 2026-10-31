import 'package:hive/hive.dart';

part 'shopping_item.g.dart';

@HiveType(typeId: 1)
class ShoppingItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  bool isBought;

  // ADICIONE ESTES DOIS CAMPOS:
  @HiveField(3)
  String categoria;

  @HiveField(4)
  String unidade;

  ShoppingItem({
    required this.name,
    this.quantity = 1,
    this.isBought = false,
    required this.categoria, // Adicione aqui
    required this.unidade,   // Adicione aqui
  });
}