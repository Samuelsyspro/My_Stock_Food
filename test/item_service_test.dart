import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/services/item_service.dart';

void main() {
  late Directory pasta;
  late ItemService service;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('prep_manager_test');
    Hive.init(pasta.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShoppingItemAdapter());
    await Hive.openBox<Item>('items');
    await Hive.openBox<ShoppingItem>('shopping_list');
    service = ItemService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await pasta.delete(recursive: true);
  });

  Item novo(
    String nome, {
    String categoria = 'Bebidas',
    String unidade = 'L',
    double quantidade = 1,
    DateTime? validade,
    double? minimo,
  }) =>
      service.criarNovo(
        nome: nome,
        categoria: categoria,
        quantidade: quantidade,
        unidade: unidade,
        validade: validade,
        quantidadeMinima: minimo,
      );

  Box<ShoppingItem> compras() => Hive.box<ShoppingItem>('shopping_list');

  group('básico', () {
    test('getAll devolve em ordem alfabética, sem ligar para acento', () async {
      await service.add(novo('Zebra'));
      await service.add(novo('água'));
      await service.add(novo('Arroz'));
      expect(service.getAll().map((i) => i.nome).toList(),
          ['água', 'Arroz', 'Zebra']);
    });

    test('ajustarQuantidade nunca fica abaixo de zero', () async {
      final item = novo('Água', quantidade: 1);
      await service.add(item);
      await service.ajustarQuantidade(item.id, -5);
      expect(service.getAll().first.quantidade, 0);
    });
  });

  group('itens antigos com chave numérica (criados com box.add)', () {
    test('ajustar, atualizar e excluir funcionam', () async {
      final item = novo('Água', quantidade: 2);
      await Hive.box<Item>('items').add(item); // chave numérica, como antes

      await service.ajustarQuantidade(item.id, 1);
      expect(item.quantidade, 3);

      item.nome = 'Água mineral';
      await service.update(item); // antes dava erro de chave
      expect(service.getAll().single.nome, 'Água mineral');

      await service.delete(item.id);
      expect(service.totalItens, 0);
    });
  });

  group('estoque mínimo → lista de compras', () {
    test('vai para a lista ao chegar no mínimo e não duplica', () async {
      final item = novo('Água', quantidade: 3, minimo: 2);
      await service.add(item);
      expect(compras().length, 0);

      final foiParaLista = await service.ajustarQuantidade(item.id, -1);
      expect(foiParaLista, isTrue);
      expect(compras().length, 1);
      expect(compras().getAt(0)!.name, 'Água');
      expect(compras().getAt(0)!.quantity, 1);

      final denovo = await service.ajustarQuantidade(item.id, -1);
      expect(denovo, isFalse);
      expect(compras().length, 1);
    });

    test('quantidade sugerida = quanto falta para o mínimo', () async {
      final item = novo('Arroz', unidade: 'kg', quantidade: 6, minimo: 5);
      await service.add(item);
      await service.ajustarQuantidade(item.id, -5); // sobra 1, mínimo 5
      expect(compras().getAt(0)!.quantity, 4);
    });

    test('item cadastrado já no mínimo vai direto para a lista', () async {
      final foi = await service.add(novo('Sal', quantidade: 1, minimo: 1));
      expect(foi, isTrue);
      expect(compras().length, 1);
    });

    test('item sem mínimo nunca vai para a lista', () async {
      final item = novo('Sal', quantidade: 1);
      await service.add(item);
      await service.ajustarQuantidade(item.id, -1);
      expect(compras().length, 0);
    });
  });

  group('adicionarOuSomar (compra)', () {
    test('soma quando nome, categoria e unidade são iguais (sem acento)', () async {
      await service.add(novo('Água', quantidade: 2));
      await service.adicionarOuSomar(
          nome: 'agua ', categoria: 'Bebidas', unidade: 'L', quantidade: 3);
      expect(service.totalItens, 1);
      expect(service.getAll().single.quantidade, 5);
    });

    test('cria outro item se a unidade for diferente', () async {
      await service.add(novo('Água', unidade: 'L'));
      await service.adicionarOuSomar(
          nome: 'Água', categoria: 'Bebidas', unidade: 'un', quantidade: 1);
      expect(service.totalItens, 2);
    });
  });

  group('unirDuplicados', () {
    test('une iguais, soma quantidade e mantém a validade mais próxima', () async {
      final a = novo('Água mineral',
          quantidade: 1, validade: DateTime(2027, 6, 1));
      final b = novo('agua mineral ',
          quantidade: 16, validade: DateTime(2027, 1, 1));
      final c = novo('Água mineral', unidade: 'un', quantidade: 4);
      for (final i in [a, b, c]) {
        await service.add(i);
      }

      final removidos = await service.unirDuplicados();

      expect(removidos, 1);
      expect(service.totalItens, 2);
      final unido =
          service.getAll().firstWhere((i) => i.unidade == 'L');
      expect(unido.quantidade, 17);
      expect(unido.validade, DateTime(2027, 1, 1));
    });

    test('sem duplicados não muda nada', () async {
      await service.add(novo('Água'));
      await service.add(novo('Arroz', categoria: 'Alimentos', unidade: 'kg'));
      expect(await service.unirDuplicados(), 0);
      expect(service.totalItens, 2);
    });
  });
}
