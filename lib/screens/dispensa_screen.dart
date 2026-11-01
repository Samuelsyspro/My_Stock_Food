import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/screens/add_edit_item_screen.dart';
import 'package:prep_manager/screens/item_list_screen.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/utils/constants.dart';
import 'package:prep_manager/widgets/alerta_card.dart';
import 'package:prep_manager/widgets/categoria_card.dart';
import 'package:prep_manager/widgets/resumo_item.dart';

class DispensaScreen extends StatefulWidget {
  const DispensaScreen({super.key});

  @override
  State<DispensaScreen> createState() => _DispensaScreenState();
}

class _DispensaScreenState extends State<DispensaScreen> {
  final ItemService _service = ItemService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispensa Digital'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _mostrarSobre(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Item>('items').listenable(),
        builder: (context, box, _) {
          final total = _service.totalItens;
          final vencidos = _service.getVencidos().length;
          final emBreve = _service.getVenceEmBreve().length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Resumo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumo do Estoque',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ResumoItem(
                            label: 'Itens',
                            valor: total.toString(),
                            cor: Colors.blue,
                            onTap: () => _abrirLista(context), // todos os itens
                          ),
                          ResumoItem(
                            label: 'Vencidos',
                            valor: vencidos.toString(),
                            cor: Colors.red,
                            onTap: () => _abrirLista(context, filtro: 'vencidos'),
                          ),
                          ResumoItem(
                            label: 'Vence em 30d',
                            valor: emBreve.toString(),
                            cor: Colors.orange,
                            onTap: () => _abrirLista(context, filtro: 'em_breve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Alertas
              if (vencidos > 0 || emBreve > 0) ...[
                if (vencidos > 0)
                  AlertaCard(
                    titulo: '$vencidos item(ns) vencido(s)',
                    cor: Colors.red,
                    onTap: () => _abrirLista(context, filtro: 'vencidos'),
                  ),
                if (emBreve > 0)
                  AlertaCard(
                    titulo: '$emBreve item(ns) vencem em 30 dias',
                    cor: Colors.orange,
                    onTap: () => _abrirLista(context, filtro: 'em_breve'),
                  ),
                const SizedBox(height: 8),
              ],

              const Text(
                'Categorias',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Grid de categorias (nomes, ícones e cores vêm do constants.dart)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: CategoriasApp.nomes.length,
                itemBuilder: (context, index) {
                  final nome = CategoriasApp.nomes[index];
                  return CategoriaCard(
                    nome: nome,
                    icone: CategoriasApp.iconeDe(nome),
                    cor: CategoriasApp.corDe(nome),
                    quantidade: _service.getByCategoria(nome).length,
                    onTap: () => _abrirLista(context, categoria: nome),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _adicionarItem(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }

  void _abrirLista(BuildContext context, {String? categoria, String? filtro}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemListScreen(
          categoria: categoria,
          filtro: filtro,
        ),
      ),
    );
    // Ao voltar, recalcula resumo, alertas e contagem por categoria
    if (mounted) setState(() {});
  }

  void _adicionarItem(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditItemScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _mostrarSobre(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispensa Digital'),
        content: const Text(
          'Gerenciador offline de estoque.\n\n'
          '• Controle de validade\n'
          '• Gerenciamento por Categorias\n'
          '• 100% offline\n'
          '• Feito para estar em sua mão!!\n\n'
          'Mantenha o estoque rotacionado (FIFO).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
