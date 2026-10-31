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

  /// Descobre a chave real do item no Hive.
  /// Itens antigos (criados pela lista de compras com add()) têm chave
  /// numérica, e os novos usam o próprio id como chave.
  dynamic _chaveDe(String id) {
    if (_box.containsKey(id)) return id;
    for (final k in _box.keys) {
      if (_box.get(k)?.id == id) return k;
    }
    return null;
  }

  Future<void> update(Item item) async {
    item.atualizadoEm = DateTime.now();
    if (item.isInBox) {
      // Já está no Hive: salva na chave em que ele realmente está
      await item.save();
    } else {
      await _box.put(item.id, item);
    }
  }

  Future<void> delete(String id) async {
    final chave = _chaveDe(id);
    if (chave != null) await _box.delete(chave);
  }

  Future<void> ajustarQuantidade(String id, double delta) async {
    final chave = _chaveDe(id);
    if (chave == null) return;
    final item = _box.get(chave);
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