import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';

class ItemService {
  final Box<Item> _box = Hive.box<Item>('items');
  final _uuid = const Uuid();

  List<Item> getAll() {
    return _box.values.toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  List<Item> getByCategoria(String categoria) {
    return _box.values.where((i) => i.categoria == categoria).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  List<Item> getVencidos() {
    return _box.values.where((i) => i.estaVencido).toList();
  }

  List<Item> getVenceEmBreve() {
    return _box.values.where((i) => i.venceEmBreve).toList();
  }

  Future<void> add(Item item) async {
    await _box.put(item.id, item);
  }

  Future<void> update(Item item) async {
    item.atualizadoEm = DateTime.now();
    await _box.put(item.id, item);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> ajustarQuantidade(String id, double delta) async {
    final item = _box.get(id);
    if (item == null) return;
    item.quantidade = (item.quantidade + delta).clamp(0, double.infinity);
    item.atualizadoEm = DateTime.now();
    await item.save();
  }

  Item criarNovo({
    required String nome,
    required String categoria,
    required double quantidade,
    required String unidade,
    DateTime? validade,
    String? localizacao,
    String? notas,
  }) {
    return Item(
      id: _uuid.v4(),
      nome: nome,
      categoria: categoria,
      quantidade: quantidade,
      unidade: unidade,
      validade: validade,
      localizacao: localizacao,
      notas: notas,
      criadoEm: DateTime.now(),
    );
  }

  Map<String, int> contagemPorCategoria() {
    final map = <String, int>{};
    for (final item in _box.values) {
      map[item.categoria] = (map[item.categoria] ?? 0) + 1;
    }
    return map;
  }

  int get totalItens => _box.length;
}
