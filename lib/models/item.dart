import 'package:hive/hive.dart';
import 'package:prep_manager/utils/helpers.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String nome;

  @HiveField(2)
  late String categoria; // Bebidas, Alimentos, Combustível, Médico, Higiene, Ferramentas, Outros

  @HiveField(3)
  late double quantidade;

  @HiveField(4)
  late String unidade; // kg, L, un, cx, etc.

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

  /// Quando a quantidade chega a esse valor (ou menos), o item vai
  /// automaticamente para a lista de compras. Vazio = sem alerta.
  @HiveField(10)
  double? quantidadeMinima;

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
    this.quantidadeMinima,
  });

  /// Vencido = a data de validade já passou (vence hoje ainda NÃO é vencido).
  bool get estaVencido {
    if (validade == null) return false;
    return somenteData(validade!).isBefore(somenteData(DateTime.now()));
  }

  /// Vence hoje ou nos próximos 30 dias.
  bool get venceEmBreve {
    final dias = diasParaVencer;
    return dias != null && dias >= 0 && dias <= 30;
  }

  /// Dias até vencer (0 = vence hoje, negativo = já venceu).
  int? get diasParaVencer {
    if (validade == null) return null;
    return somenteData(validade!).difference(somenteData(DateTime.now())).inDays;
  }

  /// Quantidade igual ou abaixo do estoque mínimo definido.
  bool get abaixoDoMinimo {
    final minimo = quantidadeMinima;
    return minimo != null && minimo > 0 && quantidade <= minimo;
  }

  // ---- Backup (converter de/para texto JSON) ----

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'categoria': categoria,
        'quantidade': quantidade,
        'unidade': unidade,
        'validade': validade?.toIso8601String(),
        'localizacao': localizacao,
        'notas': notas,
        'criadoEm': criadoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm?.toIso8601String(),
        'quantidadeMinima': quantidadeMinima,
      };

  factory Item.fromMap(Map<String, dynamic> mapa) {
    DateTime? data(dynamic valor) =>
        valor is String ? DateTime.tryParse(valor) : null;

    return Item(
      id: mapa['id'] as String,
      nome: mapa['nome'] as String,
      categoria: (mapa['categoria'] as String?) ?? 'Outros',
      quantidade: (mapa['quantidade'] as num).toDouble(),
      unidade: (mapa['unidade'] as String?) ?? 'un',
      validade: data(mapa['validade']),
      localizacao: mapa['localizacao'] as String?,
      notas: mapa['notas'] as String?,
      criadoEm: data(mapa['criadoEm']) ?? DateTime.now(),
      atualizadoEm: data(mapa['atualizadoEm']),
      quantidadeMinima: (mapa['quantidadeMinima'] as num?)?.toDouble(),
    );
  }
}
