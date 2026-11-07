import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/seguranca/backup_cripto.dart';
import 'package:prep_manager/services/backup_service.dart';
import 'package:prep_manager/services/categoria_service.dart';
import 'package:prep_manager/services/item_service.dart';

void main() {
  late Directory pasta;
  const senha = 'senha-do-backup-123';
  const rapido = 2000;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('prep_manager_bkp_prot_test');
    Hive.init(pasta.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShoppingItemAdapter());
    await Hive.openBox<Item>('items');
    await Hive.openBox<ShoppingItem>('shopping_list');
    await Hive.openBox('settings');

    final itens = ItemService();
    await itens.add(itens.criarNovo(
      nome: 'Água mineral',
      categoria: 'Bebidas',
      quantidade: 12,
      unidade: 'L',
    ));
    await CategoriaService().adicionar('Pets', 'pet');
    await Hive.box<ShoppingItem>('shopping_list')
        .add(ShoppingItem(name: 'Sabão', categoria: 'Higiene', unidade: 'un'));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await pasta.delete(recursive: true);
  });

  Future<void> apagarTudo() async {
    await Hive.box<Item>('items').clear();
    await Hive.box<ShoppingItem>('shopping_list').clear();
    await Hive.box('settings').clear();
  }

  test('o backup protegido não revela nenhum dado', () async {
    final b = await BackupService().exportarProtegido(senha, iteracoes: rapido, isolado: false);
    for (final segredo in ['Água', 'mineral', 'Sabão', 'Pets', 'prep_manager"']) {
      expect(b.texto.contains(segredo), isFalse, reason: segredo);
    }
  });

  test('exporta com senha, apaga tudo e restaura com a senha', () async {
    final b = await BackupService().exportarProtegido(senha, iteracoes: rapido, isolado: false);
    await apagarTudo();

    final r = await BackupService().importarProtegido(b.texto, senha: senha, isolado: false);

    expect(r.itensAdicionados, 1);
    expect(r.comprasAdicionadas, 1);
    expect(ItemService().getAll().single.nome, 'Água mineral');
    expect(CategoriaService().buscar('Pets'), isNotNull);
  });

  test('restaura com o código de recuperação (esqueci a senha)', () async {
    final b = await BackupService().exportarProtegido(senha, iteracoes: rapido, isolado: false);
    await apagarTudo();

    final r = await BackupService().importarProtegido(
      b.texto,
      codigoRecuperacao: b.codigoRecuperacao,
      isolado: false,
    );
    expect(r.itensAdicionados, 1);
  });

  test('senha errada não altera nenhum dado', () async {
    final b = await BackupService().exportarProtegido(senha, iteracoes: rapido, isolado: false);
    await apagarTudo();

    await expectLater(
      BackupService().importarProtegido(b.texto, senha: 'senha-errada-aaa', isolado: false),
      throwsA(isA<BackupException>()),
    );
    expect(ItemService().totalItens, 0);
  });

  test('o importar comum recusa backup protegido com mensagem clara', () async {
    final b = await BackupService().exportarProtegido(senha, iteracoes: rapido, isolado: false);
    try {
      await BackupService().importar(b.texto);
      fail('deveria ter recusado');
    } on FormatException catch (e) {
      expect(e.message.contains('protegido'), isTrue);
    }
  });

  test('backups antigos (sem proteção) continuam podendo ser restaurados', () async {
    final antigo = BackupService().exportar();
    await apagarTudo();
    final r = await BackupService().importar(antigo);
    expect(r.itensAdicionados, 1);
  });
}
