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

  // defaultValue protege dados antigos (salvos antes desses campos existirem):
  // em vez de dar erro ao abrir, eles recebem o valor padrão.
  @HiveField(3, defaultValue: 'Outros')
  String categoria;

  @HiveField(4, defaultValue: 'un')
  String unidade;

  ShoppingItem({
    required this.name,
    this.quantity = 1,
    this.isBought = false,
    required this.categoria,
    required this.unidade,
  });

  // ---- Backup (converter de/para texto JSON) ----

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'isBought': isBought,
        'categoria': categoria,
        'unidade': unidade,
      };

  factory ShoppingItem.fromMap(Map<String, dynamic> mapa) => ShoppingItem(
        name: mapa['name'] as String,
        quantity: (mapa['quantity'] as num?)?.toInt() ?? 1,
        isBought: (mapa['isBought'] as bool?) ?? false,
        categoria: (mapa['categoria'] as String?) ?? 'Outros',
        unidade: (mapa['unidade'] as String?) ?? 'un',
      );
}
