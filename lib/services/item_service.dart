import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/utils/helpers.dart';

class ItemService {
  final Box<Item> _box = Hive.box<Item>('items');
  final _uuid = const Uuid();

  Box<ShoppingItem> get _compras => Hive.box<ShoppingItem>('shopping_list');

  int _porNome(Item a, Item b) =>
      normalizar(a.nome).compareTo(normalizar(b.nome));

  List<Item> getAll() {
    return _box.values.toList()..sort(_porNome);
  }

  List<Item> getByCategoria(String categoria) {
    return _box.values.where((i) => i.categoria == categoria).toList()
      ..sort(_porNome);
  }

  List<Item> getVencidos() {
    return _box.values.where((i) => i.estaVencido).toList();
  }

  List<Item> getVenceEmBreve() {
    return _box.values.where((i) => i.venceEmBreve).toList();
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

  /// Procura na Dispensa um item com o mesmo nome, categoria e unidade
  /// (sem diferenciar maiúsculas, minúsculas e acentos).
  Item? buscarIgual(String nome, String categoria, String unidade) {
    for (final i in _box.values) {
      if (normalizar(i.nome) == normalizar(nome) &&
          normalizar(i.categoria) == normalizar(categoria) &&
          normalizar(i.unidade) == normalizar(unidade)) {
        return i;
      }
    }
    return null;
  }

  /// Salva um item novo. Devolve true se ele foi enviado para a lista de
  /// compras por estar abaixo do estoque mínimo.
  Future<bool> add(Item item) async {
    await _box.put(item.id, item);
    return enviarParaListaSeEstoqueBaixo(item);
  }

  /// Atualiza um item. Devolve true se ele foi enviado para a lista de
  /// compras por estar abaixo do estoque mínimo.
  Future<bool> update(Item item) async {
    item.atualizadoEm = DateTime.now();
    if (item.isInBox) {
      // Já está no Hive: salva na chave em que ele realmente está
      await item.save();
    } else {
      await _box.put(item.id, item);
    }
    return enviarParaListaSeEstoqueBaixo(item);
  }

  Future<void> delete(String id) async {
    final chave = _chaveDe(id);
    if (chave != null) await _box.delete(chave);
  }

  /// Soma [delta] à quantidade (nunca fica abaixo de 0).
  /// Devolve true se o item foi enviado para a lista de compras.
  Future<bool> ajustarQuantidade(String id, double delta) async {
    final chave = _chaveDe(id);
    if (chave == null) return false;
    final item = _box.get(chave);
    if (item == null) return false;

    item.quantidade = (item.quantidade + delta).clamp(0, double.infinity);
    item.atualizadoEm = DateTime.now();
    await item.save();
    return enviarParaListaSeEstoqueBaixo(item);
  }

  /// Se o item está igual ou abaixo do estoque mínimo e ainda não está na
  /// lista de compras, coloca lá. Devolve true se acabou de colocar.
  Future<bool> enviarParaListaSeEstoqueBaixo(Item item) async {
    if (!item.abaixoDoMinimo) return false;

    final jaEstaNaLista = _compras.values.any((c) =>
        normalizar(c.name) == normalizar(item.nome) &&
        normalizar(c.categoria) == normalizar(item.categoria) &&
        normalizar(c.unidade) == normalizar(item.unidade));
    if (jaEstaNaLista) return false;

    // Quanto falta para voltar ao mínimo (pelo menos 1)
    final falta = (item.quantidadeMinima! - item.quantidade).ceil();
    await _compras.add(ShoppingItem(
      name: item.nome,
      quantity: falta < 1 ? 1 : falta,
      categoria: item.categoria,
      unidade: item.unidade,
    ));
    return true;
  }

  /// Usado ao comprar: soma a quantidade num item igual (nome, categoria e
  /// unidade) ou cria um item novo na Dispensa.
  Future<void> adicionarOuSomar({
    required String nome,
    required String categoria,
    required String unidade,
    required double quantidade,
  }) async {
    final existente = buscarIgual(nome, categoria, unidade);
    if (existente != null) {
      existente.quantidade += quantidade;
      existente.atualizadoEm = DateTime.now();
      await existente.save();
    } else {
      final novo = criarNovo(
        nome: nome,
        categoria: categoria,
        quantidade: quantidade,
        unidade: unidade,
      );
      await _box.put(novo.id, novo);
    }
  }

  /// Une itens repetidos (mesmo nome, categoria e unidade) num só:
  /// soma as quantidades e fica com a validade mais próxima (o que deve ser
  /// consumido primeiro). Devolve quantos itens repetidos foram removidos.
  Future<int> unirDuplicados() async {
    final grupos = <String, List<Item>>{};
    for (final item in _box.values) {
      final chave = '${normalizar(item.nome)}|${normalizar(item.categoria)}|'
          '${normalizar(item.unidade)}';
      grupos.putIfAbsent(chave, () => []).add(item);
    }

    var removidos = 0;
    for (final grupo in grupos.values) {
      if (grupo.length < 2) continue;

      grupo.sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
      final principal = grupo.first;

      for (final outro in grupo.skip(1)) {
        principal.quantidade += outro.quantidade;

        final v = outro.validade;
        if (v != null &&
            (principal.validade == null || v.isBefore(principal.validade!))) {
          principal.validade = v;
        }

        final m = outro.quantidadeMinima;
        if (m != null && (principal.quantidadeMinima ?? 0) < m) {
          principal.quantidadeMinima = m;
        }

        if ((principal.notas ?? '').isEmpty && (outro.notas ?? '').isNotEmpty) {
          principal.notas = outro.notas;
        }
        if ((principal.localizacao ?? '').isEmpty &&
            (outro.localizacao ?? '').isNotEmpty) {
          principal.localizacao = outro.localizacao;
        }

        await outro.delete();
        removidos++;
      }

      principal.atualizadoEm = DateTime.now();
      await principal.save();
    }
    return removidos;
  }

  Item criarNovo({
    required String nome,
    required String categoria,
    required double quantidade,
    required String unidade,
    DateTime? validade,
    String? localizacao,
    String? notas,
    double? quantidadeMinima,
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
      quantidadeMinima: quantidadeMinima,
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
