import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/screens/add_edit_item_screen.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/utils/helpers.dart';
import 'package:prep_manager/widgets/item_tile.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';
import 'package:prep_manager/widgets/superficie.dart';

enum OrdemLista { nome, validade, quantidade }

class ItemListScreen extends StatefulWidget {
  final String? categoria;
  final String? filtro; // 'vencidos' | 'em_breve'

  const ItemListScreen({super.key, this.categoria, this.filtro});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final ItemService _service = ItemService();

  bool _buscando = false;
  String _busca = '';
  late OrdemLista _ordem;

  @override
  void initState() {
    super.initState();
    // Nas listas de vencimento o mais urgente aparece primeiro
    _ordem = widget.filtro != null ? OrdemLista.validade : OrdemLista.nome;
  }

  String get _titulo {
    if (widget.filtro == 'vencidos') return 'Itens Vencidos';
    if (widget.filtro == 'em_breve') return 'Vencem em 30 dias';
    return widget.categoria ?? 'Todos os Itens';
  }

  // Nas listas de vencidos / vence em 30d só se consulta, não se adiciona
  bool get _permiteAdicionar => widget.filtro == null;

  String get _mensagemVazia {
    if (_busca.trim().isNotEmpty) return 'Nenhum item encontrado para "$_busca"';
    if (widget.filtro == 'vencidos') return 'Nenhum item vencido';
    if (widget.filtro == 'em_breve') return 'Nenhum item vence em 30 dias';
    return 'Nenhum item encontrado';
  }

  List<Item> _filtrar(List<Item> todos) {
    var lista = todos;
    if (widget.filtro == 'vencidos') {
      lista = lista.where((i) => i.estaVencido).toList();
    } else if (widget.filtro == 'em_breve') {
      lista = lista.where((i) => i.venceEmBreve).toList();
    } else if (widget.categoria != null) {
      lista = lista.where((i) => i.categoria == widget.categoria).toList();
    }

    final termo = normalizar(_busca);
    if (termo.isNotEmpty) {
      lista = lista
          .where((i) =>
              normalizar(i.nome).contains(termo) ||
              normalizar(i.localizacao ?? '').contains(termo))
          .toList();
    }
    return lista;
  }

  int _porNome(Item a, Item b) =>
      normalizar(a.nome).compareTo(normalizar(b.nome));

  List<Item> _ordenar(List<Item> itens) {
    final lista = [...itens];
    switch (_ordem) {
      case OrdemLista.nome:
        lista.sort(_porNome);
      case OrdemLista.validade:
        // Quem não tem validade vai para o fim da lista
        lista.sort((a, b) {
          final va = a.validade;
          final vb = b.validade;
          if (va == null && vb == null) return _porNome(a, b);
          if (va == null) return 1;
          if (vb == null) return -1;
          return va.compareTo(vb);
        });
      case OrdemLista.quantidade:
        lista.sort((a, b) {
          final c = a.quantidade.compareTo(b.quantidade);
          return c != 0 ? c : _porNome(a, b);
        });
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return FundoScaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar item...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _busca = v),
              )
            : Text(_titulo),
        actions: [
          IconButton(
            tooltip: _buscando ? 'Fechar busca' : 'Buscar',
            icon: Icon(_buscando ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _buscando = !_buscando;
              if (!_buscando) _busca = '';
            }),
          ),
          PopupMenuButton<OrdemLista>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _ordem,
            onSelected: (o) => setState(() => _ordem = o),
            itemBuilder: (context) => const [
              PopupMenuItem(value: OrdemLista.nome, child: Text('Nome (A-Z)')),
              PopupMenuItem(
                value: OrdemLista.validade,
                child: Text('Validade (mais próxima)'),
              ),
              PopupMenuItem(
                value: OrdemLista.quantidade,
                child: Text('Quantidade (menor primeiro)'),
              ),
            ],
          ),
          if (_permiteAdicionar)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _adicionar(context),
            ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Item>('items').listenable(),
        builder: (context, box, _) {
          final itens = _ordenar(_filtrar(_service.getAll()));

          if (itens.isEmpty) {
            return Center(
              child: Superficie(
                margin: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _mensagemVazia,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  if (_permiteAdicionar && _busca.trim().isEmpty) ...[
                    const SizedBox(height: 8),
                    BotaoVidro(
                      texto: 'Adicionar item',
                      icone: Icons.add,
                      onPressed: () => _adicionar(context),
                    ),
                  ],
                ],
              )),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              return ItemTile(
                item: item,
                onEdit: () => _editar(context, item),
                onDelete: () => _confirmarExclusao(context, item),
                onMais: () => _ajustar(item, 1),
                onMenos: () => _diminuir(context, item),
              );
            },
          );
        },
      ),
    );
  }

  void _adicionar(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(categoriaInicial: widget.categoria),
      ),
    );
    // Ao voltar, força a lista a se redesenhar com os dados atuais
    if (mounted) setState(() {});
  }

  void _editar(BuildContext context, Item item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(item: item),
      ),
    );
    // Ao voltar, força a lista a se redesenhar (ex.: item mudou de categoria)
    if (mounted) setState(() {});
  }

  /// Soma ou tira da quantidade e avisa se o item foi para a lista de compras.
  Future<void> _ajustar(Item item, double delta) async {
    final foiParaLista = await _service.ajustarQuantidade(item.id, delta);
    if (foiParaLista) _avisarListaDeCompras(item);
  }

  void _avisarListaDeCompras(Item item) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${item.nome}" está acabando e foi para a lista de compras'),
      ),
    );
  }

  /// Diminui 1 da quantidade. Se chegaria a 0, pergunta se quer excluir.
  Future<void> _diminuir(BuildContext context, Item item) async {
    if (item.quantidade - 1 > 0) {
      await _ajustar(item, -1);
      return;
    }

    final excluir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantidade chegou a zero'),
        content: Text('Deseja excluir "${item.nome}" do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (excluir == true) {
      await _service.delete(item.id);
    }
  }

  void _confirmarExclusao(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text('Remover "${item.nome}" do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _service.delete(item.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
