import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../services/item_service.dart';
import '../utils/constants.dart';
import 'add_edit_item_screen.dart';

class ItemListScreen extends StatefulWidget {
  final String? categoria;
  final String? filtro; // 'vencidos' | 'em_breve'

  const ItemListScreen({super.key, this.categoria, this.filtro});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final ItemService _service = ItemService();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  String get _titulo {
    if (widget.filtro == 'vencidos') return 'Itens Vencidos';
    if (widget.filtro == 'em_breve') return 'Vencem em 30 dias';
    return widget.categoria ?? 'Todos os Itens';
  }

  // Nas listas de vencidos / vence em 30d só se consulta, não se adiciona
  bool get _permiteAdicionar => widget.filtro == null;

  String get _mensagemVazia {
    if (widget.filtro == 'vencidos') return 'Nenhum item vencido';
    if (widget.filtro == 'em_breve') return 'Nenhum item vence em 30 dias';
    return 'Nenhum item encontrado';
  }

  List<Item> _filtrar(List<Item> todos) {
    if (widget.filtro == 'vencidos') {
      return todos.where((i) => i.estaVencido).toList();
    }
    if (widget.filtro == 'em_breve') {
      return todos.where((i) => i.venceEmBreve).toList();
    }
    if (widget.categoria != null) {
      return todos.where((i) => i.categoria == widget.categoria).toList();
    }
    return todos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: [
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
          final itens = _filtrar(_service.getAll());

          if (itens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    _mensagemVazia,
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  if (_permiteAdicionar) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _adicionar(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar item'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              return _ItemTile(
                item: item,
                dateFormat: _dateFormat,
                onEdit: () => _editar(context, item),
                onDelete: () => _confirmarExclusao(context, item),
                onMais: () => _service.ajustarQuantidade(item.id, 1),
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

  /// Diminui 1 da quantidade. Se chegaria a 0, pergunta se quer excluir.
  Future<void> _diminuir(BuildContext context, Item item) async {
    if (item.quantidade - 1 > 0) {
      await _service.ajustarQuantidade(item.id, -1);
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

class _ItemTile extends StatelessWidget {
  final Item item;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMais;
  final VoidCallback onMenos;

  const _ItemTile({
    required this.item,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
    required this.onMais,
    required this.onMenos,
  });

  @override
  Widget build(BuildContext context) {
    Color? statusColor;
    String? statusText;

    if (item.estaVencido) {
      statusColor = Colors.red;
      statusText = 'VENCIDO';
    } else if (item.venceEmBreve) {
      statusColor = Colors.orange;
      statusText = 'Vence em ${item.diasParaVencer}d';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: CategoriasApp.corDe(item.categoria).withValues(alpha: 0.2),
          child: Icon(
            CategoriasApp.iconeDe(item.categoria),
            color: CategoriasApp.corDe(item.categoria),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (statusText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor!.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${item.quantidade.toStringAsFixed(item.quantidade.truncateToDouble() == item.quantidade ? 0 : 1)} ${item.unidade}'
              '${item.localizacao != null && item.localizacao!.isNotEmpty ? ' • ${item.localizacao}' : ''}',
            ),
            if (item.validade != null)
              Text(
                'Validade: ${dateFormat.format(item.validade!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor ?? Colors.grey[400],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Remover 1',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onMenos,
            ),
            IconButton(
              tooltip: 'Adicionar 1',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onMais,
            ),
          ],
        ),
        onTap: onEdit,
        onLongPress: onDelete, // segurar o item abre a confirmação de exclusão
      ),
    );
  }
}