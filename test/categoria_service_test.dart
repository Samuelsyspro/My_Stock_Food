import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/services/categoria_service.dart';
import 'package:prep_manager/services/item_service.dart';

void main() {
  late Directory pasta;
  late CategoriaService service;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('prep_manager_cat_test');
    Hive.init(pasta.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShoppingItemAdapter());
    await Hive.openBox<Item>('items');
    await Hive.openBox<ShoppingItem>('shopping_list');
    await Hive.openBox('settings');
    service = CategoriaService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await pasta.delete(recursive: true);
  });

  test('sem categorias criadas, só existem as padrão (Outros por último)', () {
    expect(service.listar(), isEmpty);
    final nomes = service.todosOsNomes();
    expect(nomes.first, 'Bebidas');
    expect(nomes.last, 'Outros');
    expect(nomes.length, 7);
  });

  test('cria uma categoria e ela aparece antes de "Outros"', () async {
    final erro = await service.adicionar('  Pets ', 'pet');
    expect(erro, isNull);

    final nomes = service.todosOsNomes();
    expect(nomes[nomes.length - 2], 'Pets');
    expect(nomes.last, 'Outros');
    expect(service.buscar('pets')!.icone, 'pet');
  });

  test('a categoria continua salva depois de fechar e abrir o Hive', () async {
    await service.adicionar('Pets', 'pet');
    await Hive.box('settings').close();
    await Hive.openBox('settings');
    expect(CategoriaService().listar().single.nome, 'Pets');
  });

  test('rejeita nome vazio, longo demais ou repetido (sem ligar para acento)', () async {
    expect(await service.adicionar('   ', 'pet'), isNotNull);
    expect(await service.adicionar('x' * 21, 'pet'), isNotNull);

    expect(await service.adicionar('Pets', 'pet'), isNull);
    expect(await service.adicionar('pets', 'pet'), isNotNull);
    expect(await service.adicionar('MÉDICO', 'pet'), isNotNull); // padrão
    expect(await service.adicionar('medico', 'pet'), isNotNull); // sem acento
    expect(service.listar().length, 1);
  });

  test('cada categoria nova recebe uma cor diferente da sequência', () async {
    await service.adicionar('A', 'pet');
    await service.adicionar('B', 'pet');
    final cores = service.listar().map((c) => c.cor).toList();
    expect(cores[0], CategoriaService.paletaCores[0]);
    expect(cores[1], CategoriaService.paletaCores[1]);
  });

  group('remover', () {
    test('remove categoria vazia', () async {
      await service.adicionar('Pets', 'pet');
      expect(await service.remover('Pets'), isNull);
      expect(service.listar(), isEmpty);
    });

    test('não remove categoria com itens', () async {
      await service.adicionar('Pets', 'pet');
      final itens = ItemService();
      await itens.add(itens.criarNovo(
        nome: 'Ração',
        categoria: 'Pets',
        quantidade: 1,
        unidade: 'kg',
      ));

      final erro = await service.remover('Pets');
      expect(erro, isNotNull);
      expect(service.listar().length, 1);
    });

    test('não remove categoria padrão', () async {
      expect(await service.remover('Bebidas'), isNotNull);
    });
  });

  test('garantir cria a categoria que faltava, uma vez só', () async {
    expect(await service.garantir('Jardim'), isTrue);
    expect(await service.garantir('jardim'), isFalse);
    expect(await service.garantir('Alimentos'), isFalse);
    expect(service.buscar('Jardim')!.icone, CategoriaService.iconePadrao);
  });
}
