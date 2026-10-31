import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart'; // Modelo da dispensa
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/utils/constants.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Abre as caixas do Hive
    final shoppingBox = Hive.box<ShoppingItem>('shopping_list');
    final pantryBox = Hive.box<Item>('items'); // Caixa da Dispensa

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
      ),
      body: ValueListenableBuilder(
        valueListenable: shoppingBox.listenable(),
        builder: (context, Box<ShoppingItem> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'Sua lista está vazia.\nAdicione um item!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final item = box.getAt(index)!;

              return CheckboxListTile(
                title: Text(item.name),
                subtitle: Text('Qtd: ${item.quantity} ${item.unidade}'),
                value: item.isBought,
                onChanged: (bool? value) async {
                  if (value != true) return;
                  await _marcarComoComprado(context, item, pantryBox);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddItemDialog(context, shoppingBox),
      ),
    );
  }

  /// Passa o item comprado para a Dispensa e remove da lista de compras.
  Future<void> _marcarComoComprado(
    BuildContext context,
    ShoppingItem item,
    Box<Item> pantryBox,
  ) async {
    final nome = item.name;

    // Procura um item igual na Dispensa: mesmo nome, categoria e unidade
    // (ignorando maiúsculas/minúsculas e espaços nas pontas)
    String norm(String s) => s.trim().toLowerCase();

    Item? itemExistente;
    for (final i in pantryBox.values) {
      if (norm(i.nome) == norm(nome) &&
          norm(i.categoria) == norm(item.categoria) &&
          norm(i.unidade) == norm(item.unidade)) {
        itemExistente = i;
        break;
      }
    }

    if (itemExistente != null) {
      // Já existe um igual: apenas soma a quantidade, sem criar outro item
      itemExistente.quantidade += item.quantity.toDouble();
      itemExistente.atualizadoEm = DateTime.now();
      await itemExistente.save();
    } else {
      // Não existe: cria um novo, usando o id como chave (igual ao ItemService)
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await pantryBox.put(
        id,
        Item(
          id: id,
          nome: nome,
          categoria: item.categoria,
          quantidade: item.quantity.toDouble(),
          unidade: item.unidade,
          criadoEm: DateTime.now(),
        ),
      );
    }

    // Remove da lista de compras
    await item.delete();

    // Avisa o usuário (só se a tela ainda existir)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nome atualizado na Dispensa!')),
      );
    }
  }

  // Janela para adicionar item
  void _showAddItemDialog(BuildContext context, Box<ShoppingItem> box) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    // Variáveis para guardar a escolha do usuário
    String selectedCategory = 'Alimentos';
    String selectedUnit = 'un';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // Necessário para atualizar os Dropdowns dentro do Dialog
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Novo Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(labelText: 'Nome do produto'),
                    ),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Quantidade'),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Categoria
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: CategoriasApp.nomes
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Unidade
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                      items: UnidadesApp.nomes
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedUnit = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final qty = int.tryParse(quantityController.text) ?? 1;

                    if (name.isNotEmpty) {
                      box.add(ShoppingItem(
                        name: name,
                        quantity: qty,
                        categoria: selectedCategory,
                        unidade: selectedUnit,
                      ));
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}