import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/utils/constants.dart';
import 'package:prep_manager/utils/helpers.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';
import 'package:google_fonts/google_fonts.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shoppingBox = Hive.box<ShoppingItem>('shopping_list');

    return FundoScaffold(
      appBar: AppBar(
        centerTitle: true, // Centraliza o título
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.format_list_numbered_sharp, // Ícone de carrinho de compras
              color: Color(0xFF07A35D), // Mesmo verde do app
              size: 26,
            ),
            const SizedBox(width: 8), // Espaço entre o ícone e o texto
            Text(
              'Lista de Compras',
              style: GoogleFonts.rochester(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: shoppingBox.listenable(),
        builder: (context, Box<ShoppingItem> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Vidro(
                margin: const EdgeInsets.all(24),
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sua lista está vazia.\nAdicione um item!',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            // Espaço embaixo para o botão flutuante não cobrir o último item
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: box.length,
            itemBuilder: (context, index) {
              final item = box.getAt(index)!;
              final cor = CategoriasApp.corDe(item.categoria);

              return Vidro(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                borderRadius: BorderRadius.circular(16),
                child: CheckboxListTile(
                  secondary:
                      Icon(CategoriasApp.iconeDe(item.categoria), color: cor),
                  title: Text(item.name),
                  subtitle: Text('Qtd: ${item.quantity} ${item.unidade}'),
                  value: item.isBought,
                  onChanged: (bool? value) async {
                    if (value != true) return;
                    await _marcarComoComprado(context, item);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FabVidro(
        icone: Icons.add,
        onPressed: () => _showAddItemDialog(context, shoppingBox),
      ),
    );
  }

  /// Passa o item comprado para a Dispensa e remove da lista de compras.
  /// Se já existir na Dispensa um item com o mesmo nome, categoria e unidade,
  /// apenas soma a quantidade (sem criar outro item).
  Future<void> _marcarComoComprado(
      BuildContext context, ShoppingItem item) async {
    final nome = item.name;

    await ItemService().adicionarOuSomar(
      nome: nome,
      categoria: item.categoria,
      unidade: item.unidade,
      quantidade: item.quantity.toDouble(),
    );

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
    final quantityController = TextEditingController(text: '1');
    // O campo de nome é criado pelo Autocomplete; guardamos o controlador aqui
    TextEditingController? nameController;

    // Itens que já existem na Dispensa (usados como sugestão)
    final sugestoes = ItemService().getAll();

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
                    // Nome com sugestões da Dispensa
                    Autocomplete<Item>(
                      displayStringForOption: (i) => i.nome,
                      optionsBuilder: (TextEditingValue valor) {
                        final termo = normalizar(valor.text);
                        if (termo.isEmpty) return const Iterable<Item>.empty();
                        return sugestoes
                            .where((i) => normalizar(i.nome).contains(termo));
                      },
                      onSelected: (Item escolhido) {
                        // Aproveita a categoria e a unidade do item da Dispensa
                        setState(() {
                          if (CategoriasApp.nomes
                              .contains(escolhido.categoria)) {
                            selectedCategory = escolhido.categoria;
                          }
                          if (UnidadesApp.nomes.contains(escolhido.unidade)) {
                            selectedUnit = escolhido.unidade;
                          }
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        nameController = controller;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              labelText: 'Nome do produto'),
                        );
                      },
                    ),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Quantidade'),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Categoria
                    // (a key faz o campo se atualizar quando uma sugestão é escolhida)
                    DropdownButtonFormField<String>(
                      key: ValueKey('categoria-$selectedCategory'),
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: CategoriasApp.nomes
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Unidade
                    DropdownButtonFormField<String>(
                      key: ValueKey('unidade-$selectedUnit'),
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                      items: UnidadesApp.nomes
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController?.text.trim() ?? '';
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
