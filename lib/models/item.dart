import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String nome;

  @HiveField(2)
  late String categoria; // Agua, Alimentos, Combustivel, Medico, Higiene, Ferramentas, Outros

  @HiveField(3)
  late double quantidade;

  @HiveField(4)
  late String unidade; // kg, L, un, caixa, etc.

  @HiveField(5)
  DateTime? validade;

  @HiveField(6)
  String? localizacao; // armário, despensa, garagem...

  @HiveField(7)
  String? notas;

  @HiveField(8)
  late DateTime criadoEm;

  @HiveField(9)
  DateTime? atualizadoEm;

  Item({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.quantidade,
    required this.unidade,
    this.validade,
    this.localizacao,
    this.notas,
    required this.criadoEm,
    this.atualizadoEm,
  });

  bool get estaVencido {
    if (validade == null) return false;
    return validade!.isBefore(DateTime.now());
  }

  bool get venceEmBreve {
    if (validade == null) return false;
    final dias = validade!.difference(DateTime.now()).inDays;
    return dias >= 0 && dias <= 30;
  }

  int? get diasParaVencer {
    if (validade == null) return null;
    return validade!.difference(DateTime.now()).inDays;
  }
}
