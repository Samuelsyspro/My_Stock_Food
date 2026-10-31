import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart'; // Seu modelo da dispensa
import 'package:prep_manager/models/shopping_item.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Abre as caixas do Hive
    final shoppingBox = Hive.box<ShoppingItem>('shopping_list');
    final pantryBox = Hive.box<Item>('items'); // A caixa da sua Dispensa

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
      ),
      body: ValueListenableBuilder(
        valueListenable: shoppingBox.listenable(),
        builder: (context, Box<ShoppingItem> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('Sua lista está vazia.\nAdicione um item!'),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final item = box.getAt(index)!;

              return CheckboxListTile(
                title: Text(item.name),
                subtitle: Text('Qtd: ${item.quantity}'),
                value: item.isBought,
                onChanged: (bool? value) {
                  // Lógica de integração com a Dispensa
                  if (value == true) {
                    // 1. Adiciona na Dispensa
                    pantryBox.add(Item(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      nome: item.name,
                      categoria: item
                          .categoria, // <-- Pega a categoria que o usuário escolheu
                      quantidade: item.quantity.toDouble(),
                      unidade: item
                          .unidade, // <-- Pega a unidade que o usuário escolheu
                      criadoEm: DateTime.now(),
                    ));

                    // 2. Remove da lista de compras (ou apenas marca como comprado)
                    // Aqui vamos deletar para a lista não ficar cheia de itens riscados
                    box.deleteAt(index);

                    // Mostra um aviso pro usuário
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('${item.name} adicionado à Dispensa!')),
                    );
                  }
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

  // Função para abrir a janela de adicionar item
  void _showAddItemDialog(BuildContext context, Box<ShoppingItem> box) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    // Variáveis para guardar a escolha do usuário
    String selectedCategory = 'Alimentos';
    String selectedUnit = 'un';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Necessário para atualizar o Dropdown dentro do Dialog
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Novo Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
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
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        'Bebidas',
                        'Alimentos',
                        'Combustível',
                        'Médico',
                        'Higiene',
                        'Ferramentas',
                        'Outros'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Unidade
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                      items: ['un', 'kg', 'g', 'L', 'ml', 'cx']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedUnit = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
                        categoria:
                            selectedCategory, // <-- Salva a categoria escolhida
                        unidade: selectedUnit, // <-- Salva a unidade escolhida
                      ));
                      Navigator.pop(context);
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
