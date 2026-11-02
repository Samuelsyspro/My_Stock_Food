import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/utils/constants.dart';
import 'package:prep_manager/utils/helpers.dart';
import 'package:prep_manager/widgets/vidro.dart';

/// Linha de um item da Dispensa: ícone da categoria, nome, quantidade,
/// validade e botões de − e +.
class ItemTile extends StatelessWidget {
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  final Item item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMais;
  final VoidCallback onMenos;

  const ItemTile({
    super.key,
    required this.item,
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
      statusText =
          item.diasParaVencer == 0 ? 'Vence hoje' : 'Vence em ${item.diasParaVencer}d';
    }

    final cor = CategoriasApp.corDe(item.categoria);
    final local = item.localizacao;

    return Vidro(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.2),
          child: Icon(CategoriasApp.iconeDe(item.categoria), color: cor),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${formatarQuantidade(item.quantidade)} ${item.unidade}'
              '${local != null && local.isNotEmpty ? ' • $local' : ''}',
            ),
            if (item.validade != null)
              Text(
                'Validade: ${_dateFormat.format(item.validade!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (item.abaixoDoMinimo)
              Text(
                'Estoque baixo (mín. ${formatarQuantidade(item.quantidadeMinima!)} ${item.unidade})',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
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
