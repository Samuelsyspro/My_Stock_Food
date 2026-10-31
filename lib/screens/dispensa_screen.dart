import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../services/item_service.dart';
import 'add_edit_item_screen.dart';
import 'item_list_screen.dart';

class DispensaScreen extends StatefulWidget {
  const DispensaScreen({super.key});

  @override
  State<DispensaScreen> createState() => _DispensaScreenState();
}

class _DispensaScreenState extends State<DispensaScreen> {
  final ItemService _service = ItemService();

  static const categorias = [
    {'nome': 'Bebidas', 'icone': Icons.liquor, 'cor': Color(0xFF0288D1)},
    {'nome': 'Alimentos', 'icone': Icons.restaurant, 'cor': Color(0xFF388E3C)},
    {'nome': 'Combustível', 'icone': Icons.local_gas_station, 'cor': Color(0xFFF57C00)},
    {'nome': 'Médico', 'icone': Icons.medical_services, 'cor': Color(0xFFD32F2F)},
    {'nome': 'Higiene', 'icone': Icons.soap, 'cor': Color(0xFF7B1FA2)},
    {'nome': 'Ferramentas', 'icone': Icons.build, 'cor': Color(0xFF455A64)},
    {'nome': 'Outros', 'icone': Icons.inventory_2, 'cor': Color(0xFF5D4037)},
  ];

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
                          _ResumoItem(
                            label: 'Itens',
                            valor: total.toString(),
                            cor: Colors.blue,
                            onTap: () => _abrirLista(context), // todos os itens
                          ),
                          _ResumoItem(
                            label: 'Vencidos',
                            valor: vencidos.toString(),
                            cor: Colors.red,
                            onTap: () => _abrirLista(context, filtro: 'vencidos'),
                          ),
                          _ResumoItem(
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
                  _AlertaCard(
                    titulo: '$vencidos item(ns) vencido(s)',
                    cor: Colors.red,
                    onTap: () => _abrirLista(context, filtro: 'vencidos'),
                  ),
                if (emBreve > 0)
                  _AlertaCard(
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

              // Grid de categorias
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final cat = categorias[index];
                  final count = _service.getByCategoria(cat['nome'] as String).length;
                  return _CategoriaCard(
                    nome: cat['nome'] as String,
                    icone: cat['icone'] as IconData,
                    cor: cat['cor'] as Color,
                    quantidade: count,
                    onTap: () => _abrirLista(context, categoria: cat['nome'] as String),
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

class _ResumoItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final VoidCallback onTap;

  const _ResumoItem({
    required this.label,
    required this.valor,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _AlertaCard extends StatelessWidget {
  final String titulo;
  final Color cor;
  final VoidCallback onTap;

  const _AlertaCard({required this.titulo, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cor.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: cor),
        title: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final String nome;
  final IconData icone;
  final Color cor;
  final int quantidade;
  final VoidCallback onTap;

  const _CategoriaCard({
    required this.nome,
    required this.icone,
    required this.cor,
    required this.quantidade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 32, color: cor),
              const SizedBox(height: 8),
              Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              Text(
                '$quantidade item(ns)',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}