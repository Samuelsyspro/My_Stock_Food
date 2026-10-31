import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../services/item_service.dart';
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
                    'Nenhum item encontrado',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _adicionar(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar item'),
                  ),
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
                onAjustar: (delta) => _service.ajustarQuantidade(item.id, delta),
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
  }

  void _editar(BuildContext context, Item item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditItemScreen(item: item),
      ),
    );
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
  final Function(double) onAjustar;

  const _ItemTile({
    required this.item,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
    required this.onAjustar,
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == '+1') onAjustar(1);
            if (value == '-1') onAjustar(-1);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: '+1', child: Text('+1 unidade')),
            const PopupMenuItem(value: '-1', child: Text('-1 unidade')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
