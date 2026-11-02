import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/screens/item_list_screen.dart';
import 'package:prep_manager/services/categoria_service.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/utils/constants.dart';
import 'package:prep_manager/widgets/alerta_card.dart';
import 'package:prep_manager/widgets/categoria_card.dart';
import 'package:prep_manager/widgets/resumo_item.dart';
import 'package:prep_manager/widgets/seletor_icone.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';
import 'package:google_fonts/google_fonts.dart';

class DispensaScreen extends StatefulWidget {
  const DispensaScreen({super.key});

  @override
  State<DispensaScreen> createState() => _DispensaScreenState();
}

class _DispensaScreenState extends State<DispensaScreen> {
  final ItemService _service = ItemService();
  final CategoriaService _categorias = CategoriaService();

  @override
  Widget build(BuildContext context) {
    return FundoScaffold(
      appBar: AppBar(
        centerTitle: true, 
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.kitchen,
              color: Color(0xFF07A35D), 
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Despensa Digital',
              style: GoogleFonts.rochester(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
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
          final nomesCategorias = CategoriasApp.nomes;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // Resumo
              Vidro(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumo do Estoque',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ResumoItem(
                            label: 'Itens',
                            valor: total.toString(),
                            cor: Colors.blue,
                            onTap: () => _abrirLista(context), 
                          ),
                          ResumoItem(
                            label: 'Vencidos',
                            valor: vencidos.toString(),
                            cor: Colors.red,
                            onTap: () =>
                                _abrirLista(context, filtro: 'vencidos'),
                          ),
                          ResumoItem(
                            label: 'Vence em 30d',
                            valor: emBreve.toString(),
                            cor: Colors.orange,
                            onTap: () =>
                                _abrirLista(context, filtro: 'em_breve'),
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

              Vidro(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categorias',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_categorias.listar().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Segure uma categoria criada por você para excluí-la.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: nomesCategorias.length,
                itemBuilder: (context, index) {
                  final nome = nomesCategorias[index];
                  return CategoriaCard(
                    nome: nome,
                    icone: CategoriasApp.iconeDe(nome),
                    cor: CategoriasApp.corDe(nome),
                    quantidade: _service.getByCategoria(nome).length,
                    onTap: () => _abrirLista(context, categoria: nome),
                    onLongPress: _categorias.ehPadrao(nome)
                        ? null
                        : () => _confirmarRemocao(context, nome),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FabVidro(
        icone: Icons.add,
        texto: 'Categoria',
        onPressed: () => _novaCategoria(context),
      ),
    );
  }

  void _abrirLista(BuildContext context,
      {String? categoria, String? filtro}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemListScreen(
          categoria: categoria,
          filtro: filtro,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _novaCategoria(BuildContext context) async {
    final nomeCtrl = TextEditingController();
    var iconeEscolhido = CategoriaService.iconePadrao;
    String? erro;

    final criada = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Nova categoria'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nomeCtrl,
                    autofocus: true,
                    maxLength: CategoriaService.tamanhoMaximoNome,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nome da categoria',
                      errorText: erro,
                    ),
                    onChanged: (_) {
                      if (erro != null) setStateDialog(() => erro = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text('Ícone',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SeletorIcone(
                    icones: CategoriasApp.catalogoIcones,
                    selecionado: iconeEscolhido,
                    onSelecionar: (chave) =>
                        setStateDialog(() => iconeEscolhido = chave),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final mensagem =
                    await _categorias.adicionar(nomeCtrl.text, iconeEscolhido);
                if (mensagem != null) {
                  setStateDialog(() => erro = mensagem);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (criada == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Categoria criada! Toque nela para cadastrar itens.'),
        ),
      );
    }
  }

  Future<void> _confirmarRemocao(BuildContext context, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir categoria?'),
        content: Text('Remover a categoria "$nome"?'),
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
    if (confirmar != true) return;

    final mensagem = await _categorias.remover(nome);
    if (!mounted) return;
    setState(() {});
    if (mensagem != null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    }
  }

  void _mostrarSobre(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Despensa Digital'),
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
