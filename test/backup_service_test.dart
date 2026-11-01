import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/services/backup_service.dart';
import 'package:prep_manager/services/item_service.dart';

void main() {
  late Directory pasta;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('prep_manager_backup_test');
    Hive.init(pasta.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShoppingItemAdapter());
    await Hive.openBox<Item>('items');
    await Hive.openBox<ShoppingItem>('shopping_list');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await pasta.delete(recursive: true);
  });

  Future<void> popular() async {
    final service = ItemService();
    await service.add(service.criarNovo(
      nome: 'Água',
      categoria: 'Bebidas',
      quantidade: 12,
      unidade: 'L',
      validade: DateTime(2027, 3, 1),
      quantidadeMinima: 4,
    ));
    await service.add(service.criarNovo(
      nome: 'Arroz',
      categoria: 'Alimentos',
      quantidade: 2.5,
      unidade: 'kg',
    ));
    await Hive.box<ShoppingItem>('shopping_list').add(
      ShoppingItem(name: 'Sabão', categoria: 'Higiene', unidade: 'un'),
    );
  }

  test('exporta e restaura os dados depois de apagar tudo', () async {
    await popular();
    final texto = BackupService().exportar();

    await Hive.box<Item>('items').clear();
    await Hive.box<ShoppingItem>('shopping_list').clear();

    final r = await BackupService().importar(texto);

    expect(r.itensAdicionados, 2);
    expect(r.itensAtualizados, 0);
    expect(r.comprasAdicionadas, 1);
    expect(r.ignorados, 0);

    final itens = ItemService().getAll();
    expect(itens.map((i) => i.nome).toList(), ['Água', 'Arroz']);
    expect(itens.first.quantidade, 12);
    expect(itens.first.validade, DateTime(2027, 3, 1));
    expect(itens.first.quantidadeMinima, 4);
    expect(Hive.box<ShoppingItem>('shopping_list').getAt(0)!.name, 'Sabão');
  });

  test('restaurar duas vezes não duplica nada', () async {
    await popular();
    final texto = BackupService().exportar();

    final r = await BackupService().importar(texto);

    expect(r.itensAdicionados, 0);
    expect(r.itensAtualizados, 2);
    expect(r.comprasAdicionadas, 0);
    expect(Hive.box<Item>('items').length, 2);
    expect(Hive.box<ShoppingItem>('shopping_list').length, 1);
  });

  test('texto inválido lança FormatException', () async {
    await expectLater(
      BackupService().importar('isto não é json'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      BackupService().importar('{"app": "outro"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('item com dados quebrados é ignorado e o resto é restaurado', () async {
    const texto = '''
    {"app":"prep_manager","versao":1,
     "itens":[
       {"id":"1","nome":"Sal","quantidade":1},
       {"id":"2","nome":"Sem quantidade"}
     ],
     "compras":[]}''';

    final r = await BackupService().importar(texto);

    expect(r.itensAdicionados, 1);
    expect(r.ignorados, 1);
  });
}
