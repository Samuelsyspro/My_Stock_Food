import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/seguranca/armazenamento_seguro.dart';
import 'package:prep_manager/seguranca/dados_seguros.dart';

void main() {
  late Directory pasta;
  late ArmazenamentoMemoria st;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('prep_manager_seg_test');
    Hive.init(pasta.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ShoppingItemAdapter());
    st = ArmazenamentoMemoria();
  });

  tearDown(() async {
    await Hive.close();
    if (pasta.existsSync()) await pasta.delete(recursive: true);
  });

  Item item(String id, String nome, {double q = 1}) => Item(
        id: id,
        nome: nome,
        categoria: 'Bebidas',
        quantidade: q,
        unidade: 'L',
        validade: DateTime(2027, 3, 1),
        criadoEm: DateTime(2026, 1, 1),
        quantidadeMinima: 2,
      );

  bool arquivoContem(String nomeCaixa, String texto) {
    final bytes = File('${pasta.path}/$nomeCaixa.hive').readAsBytesSync();
    final alvo = utf8.encode(texto);
    for (var i = 0; i <= bytes.length - alvo.length; i++) {
      var igual = true;
      for (var j = 0; j < alvo.length; j++) {
        if (bytes[i + j] != alvo[j]) {
          igual = false;
          break;
        }
      }
      if (igual) return true;
    }
    return false;
  }

  /// Cria os dados "antigos": caixas SEM criptografia, como o app era antes.
  Future<void> criarDadosAntigos() async {
    final itens = await Hive.openBox<Item>('items');
    await itens.put('id-1', item('id-1', 'Água mineral', q: 12));
    await itens.add(item('id-2', 'Arroz integral')); // chave numérica, como o código antigo fazia
    final compras = await Hive.openBox<ShoppingItem>('shopping_list');
    await compras.add(ShoppingItem(name: 'Sabão em pó', categoria: 'Higiene', unidade: 'un'));
    final config = await Hive.openBox('settings');
    await config.put('fundo_ativo', false);
    await config.put('categorias_personalizadas', [
      {'nome': 'Pets', 'icone': 'pet', 'cor': 4278190080},
    ]);
    await Hive.close();
  }

  group('instalação nova', () {
    test('cria a chave, abre as caixas criptografadas e guarda dados', () async {
      await DadosSeguros(st).iniciar();

      expect(st.dados['hive_chave'], isNotNull);
      expect(base64Decode(st.dados['hive_chave']!).length, 32); // 256 bits
      expect(st.dados['dados_criptografados_v1'], '1');

      await Hive.box<Item>('items').put('a', item('a', 'Segredo do Joao'));
      await Hive.close();

      expect(arquivoContem('items', 'Segredo do Joao'), isFalse); // criptografado em disco

      await DadosSeguros(st).iniciar(); // "reabriu o app"
      expect(Hive.box<Item>('items').get('a')!.nome, 'Segredo do Joao');
    });

    test('cada instalação recebe uma chave diferente', () async {
      await DadosSeguros(st).iniciar();
      final primeira = st.dados['hive_chave'];
      await Hive.close();
      await Hive.deleteFromDisk();

      final outro = ArmazenamentoMemoria();
      await DadosSeguros(outro).iniciar();
      expect(outro.dados['hive_chave'] == primeira, isFalse);
    });
  });

  group('migração dos dados antigos', () {
    test('(controle) antes da migração, o nome aparece em texto no arquivo', () async {
      await criarDadosAntigos();
      expect(arquivoContem('items', 'Água mineral'), isTrue);
    });

    test('copia tudo, mantém as chaves e criptografa em disco', () async {
      await criarDadosAntigos();

      await DadosSeguros(st).iniciar();

      final itens = Hive.box<Item>('items');
      expect(itens.length, 2);
      final agua = itens.get('id-1')!;
      expect(agua.nome, 'Água mineral');
      expect(agua.quantidade, 12);
      expect(agua.validade, DateTime(2027, 3, 1));
      expect(agua.quantidadeMinima, 2);
      expect(itens.keys.whereType<int>().length, 1); // a chave numérica foi mantida
      expect(itens.values.any((i) => i.nome == 'Arroz integral'), isTrue);

      expect(Hive.box<ShoppingItem>('shopping_list').getAt(0)!.name, 'Sabão em pó');

      final config = Hive.box('settings');
      expect(config.get('fundo_ativo'), false);
      expect((config.get('categorias_personalizadas') as List).length, 1);

      await Hive.close();
      expect(arquivoContem('items', 'Água mineral'), isFalse);
      expect(arquivoContem('items', 'Arroz integral'), isFalse);
      expect(arquivoContem('shopping_list', 'Sabão'), isFalse);

      // as caixas temporárias não ficam para trás
      for (final nome in DadosSeguros.nomesCaixas) {
        expect(File('${pasta.path}/${nome}__tmp.hive').existsSync(), isFalse);
      }
    });

    test('abrir de novo depois de migrar não perde nada', () async {
      await criarDadosAntigos();
      await DadosSeguros(st).iniciar();
      await Hive.close();

      await DadosSeguros(st).iniciar();
      expect(Hive.box<Item>('items').length, 2);
    });

    test('objetos migrados funcionam normalmente (salvar, excluir)', () async {
      await criarDadosAntigos();
      await DadosSeguros(st).iniciar();

      final agua = Hive.box<Item>('items').get('id-1')!;
      agua.quantidade = 5;
      await agua.save();
      expect(Hive.box<Item>('items').get('id-1')!.quantidade, 5);

      await agua.delete();
      expect(Hive.box<Item>('items').length, 1);
    });
  });

  group('migração interrompida (o app fechou no meio)', () {
    test('cópia temporária completa: termina a partir dela', () async {
      await criarDadosAntigos();

      // simula: cópia temporária pronta e confirmada, mas a original ainda existe
      final chave = Hive.generateSecureKey();
      await st.gravar('hive_chave', base64Encode(chave));
      final cifra = HiveAesCipher(chave);
      final tmp = await Hive.openBox('items__tmp', encryptionCipher: cifra);
      await tmp.put('id-1', item('id-1', 'Água mineral', q: 12));
      await tmp.close();
      await st.gravar('migracao_items', 'tmp'); // a cópia foi confirmada como completa

      await DadosSeguros(st).iniciar();

      expect(Hive.box<Item>('items').get('id-1')!.nome, 'Água mineral');
      expect(File('${pasta.path}/items__tmp.hive').existsSync(), isFalse);
    });

    test('cópia temporária incompleta: descarta e refaz da original', () async {
      await criarDadosAntigos();

      final chave = Hive.generateSecureKey();
      await st.gravar('hive_chave', base64Encode(chave));
      final tmp = await Hive.openBox('items__tmp', encryptionCipher: HiveAesCipher(chave));
      await tmp.put('so-um', item('so-um', 'Item pela metade')); // estado não foi marcado
      await tmp.close();

      await DadosSeguros(st).iniciar();

      final itens = Hive.box<Item>('items');
      expect(itens.length, 2); // os dados ORIGINAIS, não os da cópia incompleta
      expect(itens.get('so-um'), isNull);
      expect(itens.get('id-1')!.nome, 'Água mineral');
    });

    test('migração terminou mas a marca não foi salva: não perde dados', () async {
      await criarDadosAntigos();
      await DadosSeguros(st).iniciar();
      await Hive.close();

      st.dados.remove('dados_criptografados_v1'); // simula a falha ao gravar a marca

      await DadosSeguros(st).iniciar();
      expect(Hive.box<Item>('items').length, 2);
      expect(Hive.box<Item>('items').get('id-1')!.nome, 'Água mineral');
    });
  });

  group('quando o armazenamento seguro perde informação', () {
    test('perdeu a marca e os estados: recusa abrir, sem apagar nem cortar os dados', () async {
      await criarDadosAntigos();
      await DadosSeguros(st).iniciar();
      await Hive.close();

      final tamanho = File('${pasta.path}/items.hive').lengthSync();
      // perda parcial: ficou a chave, mas sumiram a marca e o estado de cada caixa
      st.dados.removeWhere((k, _) => k == 'dados_criptografados_v1' || k.startsWith('migracao_'));

      await expectLater(DadosSeguros(st).iniciar(), throwsA(isA<DadosIlegiveis>()));
      await Hive.close();

      expect(File('${pasta.path}/items.hive').lengthSync(), tamanho); // nada foi cortado

      // restaurando as informações, tudo volta a abrir
      st.dados['dados_criptografados_v1'] = '1';
      await DadosSeguros(st).iniciar();
      expect(Hive.box<Item>('items').length, 2);
    });
  });

  group('quando a chave não serve mais', () {
    test('marca de migrado, mas sem chave: avisa que a chave foi perdida', () async {
      await DadosSeguros(st).iniciar();
      await Hive.close();
      st.dados.remove('hive_chave');

      await expectLater(DadosSeguros(st).iniciar(), throwsA(isA<ChaveDadosPerdida>()));
    });

    test('chave diferente da usada nos dados: dados ilegíveis, sem apagar nada', () async {
      await DadosSeguros(st).iniciar();
      await Hive.box<Item>('items').put('a', item('a', 'Meu item'));
      await Hive.close();

      final tamanhoAntes = File('${pasta.path}/items.hive').lengthSync();
      st.dados['hive_chave'] = base64Encode(Hive.generateSecureKey());

      await expectLater(DadosSeguros(st).iniciar(), throwsA(isA<DadosIlegiveis>()));
      await Hive.close();

      // o arquivo continua intacto: com a chave certa, ainda dá para abrir
      expect(File('${pasta.path}/items.hive').lengthSync(), tamanhoAntes);
    });

    test('arquivo com o final danificado: recusa, e só recupera se o usuário pedir', () async {
      await DadosSeguros(st).iniciar();
      final itens = Hive.box<Item>('items');
      await itens.put('a', item('a', 'Primeiro'));
      await itens.put('b', item('b', 'Segundo'));
      await Hive.close();

      // simula o celular desligando no meio de uma gravação: lixo no final do arquivo
      final arquivo = File('${pasta.path}/items.hive');
      final original = arquivo.lengthSync();
      arquivo.writeAsBytesSync([1, 2, 3, 4, 5], mode: FileMode.append);

      await expectLater(DadosSeguros(st).iniciar(), throwsA(isA<DadosIlegiveis>()));
      await Hive.close();
      expect(arquivo.lengthSync(), original + 5); // nada foi cortado por conta própria

      await DadosSeguros(st).iniciar(recuperar: true);
      expect(Hive.box<Item>('items').length, 2); // os dados de antes continuam
      expect(Hive.box<Item>('items').get('b')!.nome, 'Segundo');
    });

    test('apagarTudo limpa os dados e a chave, e dá para recomeçar', () async {
      await DadosSeguros(st).iniciar();
      await Hive.box<Item>('items').put('a', item('a', 'Meu item'));

      await DadosSeguros(st).apagarTudo();
      expect(st.dados.containsKey('hive_chave'), isFalse);
      expect(st.dados.containsKey('dados_criptografados_v1'), isFalse);

      await DadosSeguros(st).iniciar();
      expect(Hive.box<Item>('items').length, 0);
    });
  });
}
