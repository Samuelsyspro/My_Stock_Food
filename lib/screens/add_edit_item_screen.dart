import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';
import '../services/item_service.dart';
import '../utils/constants.dart';

class AddEditItemScreen extends StatefulWidget {
  final Item? item;
  final String? categoriaInicial;

  const AddEditItemScreen({super.key, this.item, this.categoriaInicial});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ItemService();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  late TextEditingController _nomeCtrl;
  late TextEditingController _qtdCtrl;
  late TextEditingController _unidadeCtrl;
  late TextEditingController _localCtrl;
  late TextEditingController _notasCtrl;

  String _categoria = 'Alimentos';
  DateTime? _validade;

  static const categorias = CategoriasApp.nomes;

  static const unidadesComuns = UnidadesApp.nomes;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nomeCtrl = TextEditingController(text: item?.nome ?? '');
    _qtdCtrl = TextEditingController(
      text: item != null ? item.quantidade.toString() : '1',
    );
    _unidadeCtrl = TextEditingController(text: item?.unidade ?? 'un');
    _localCtrl = TextEditingController(text: item?.localizacao ?? '');
    _notasCtrl = TextEditingController(text: item?.notas ?? '');
    _categoria = item?.categoria ?? widget.categoriaInicial ?? 'Alimentos';
    _validade = item?.validade;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _qtdCtrl.dispose();
    _unidadeCtrl.dispose();
    _localCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final qtd = double.tryParse(_qtdCtrl.text.replaceAll(',', '.')) ?? 0;

    try {
      if (_isEdit) {
        final item = widget.item!;
        item.nome = _nomeCtrl.text.trim();
        item.categoria = _categoria;
        item.quantidade = qtd;
        item.unidade = _unidadeCtrl.text.trim();
        item.validade = _validade;
        item.localizacao = _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim();
        item.notas = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
        await _service.update(item);
      } else {
        final novo = _service.criarNovo(
          nome: _nomeCtrl.text.trim(),
          categoria: _categoria,
          quantidade: qtd,
          unidade: _unidadeCtrl.text.trim(),
          validade: _validade,
          localizacao: _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
        await _service.add(novo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _validade ?? agora.add(const Duration(days: 180)),
      firstDate: DateTime(2020),
      lastDate: DateTime(agora.year + 15),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() => _validade = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar Item' : 'Novo Item'),
        actions: [
          TextButton(
            onPressed: _salvar,
            child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do item *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _qtdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unidadeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: unidadesComuns
                  .map((u) => ActionChip(
                        label: Text(u),
                        onPressed: () => setState(() => _unidadeCtrl.text = u),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de validade',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: _validade != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _validade = null),
                        )
                      : null,
                ),
                child: Text(
                  _validade != null ? _dateFormat.format(_validade!) : 'Sem validade / Não definida',
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _localCtrl,
              decoration: const InputDecoration(
                labelText: 'Localização (opcional)',
                hintText: 'Ex: despensa, armário da cozinha, garagem',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? 'Atualizar' : 'Adicionar ao estoque'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}