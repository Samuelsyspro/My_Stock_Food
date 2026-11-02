import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prep_manager/services/fundo_service.dart';

void main() {
  group('filtrarImagens', () {
    const arquivos = [
      'assets/inicial2.png',
      'assets/background/DarkMode/b.jpg',
      'assets/background/DarkMode/a.PNG',
      'assets/background/DarkMode/leia-me.txt',
      'assets/background/DarkMode/d.jfif',
      'assets/background/LightMode/c.webp',
      'assets/icons/icone.png',
    ];

    test('separa as imagens de cada modo, ignorando maiúsculas da pasta', () {
      expect(FundoService.filtrarImagens(arquivos, FundoService.pastaEscuro), [
        'assets/background/DarkMode/a.PNG',
        'assets/background/DarkMode/b.jpg',
        'assets/background/DarkMode/d.jfif',
      ]);
      expect(FundoService.filtrarImagens(arquivos, FundoService.pastaClaro), [
        'assets/background/LightMode/c.webp',
      ]);
    });

    test('pasta sem imagens resulta em lista vazia', () {
      expect(FundoService.filtrarImagens([], FundoService.pastaClaro), isEmpty);
      expect(
        FundoService.filtrarImagens(['assets/inicial2.png'], FundoService.pastaEscuro),
        isEmpty,
      );
    });
  });

  group('escolher', () {
    final imagens = ['a.png', 'b.png', 'c.png'];

    test('sem imagens devolve null', () {
      expect(FundoService.escolher([]), isNull);
    });

    test('com uma só imagem, usa ela mesmo repetindo', () {
      expect(FundoService.escolher(['a.png'], ultima: 'a.png'), 'a.png');
    });

    test('nunca repete a imagem da vez anterior', () {
      final random = Random(1);
      for (var i = 0; i < 300; i++) {
        final r = FundoService.escolher(imagens, ultima: 'b.png', random: random);
        expect(r == 'b.png', isFalse);
      }
    });

    test('todas as outras imagens aparecem', () {
      final random = Random(2);
      final vistas = <String>{};
      for (var i = 0; i < 100; i++) {
        vistas.add(FundoService.escolher(imagens, ultima: 'a.png', random: random)!);
      }
      expect(vistas.length, 2);
      expect(vistas.contains('b.png'), isTrue);
      expect(vistas.contains('c.png'), isTrue);
      expect(vistas.contains('a.png'), isFalse);
    });
  });

  group('sortear e imagemPara (com o Hive)', () {
    late Directory pasta;

    const arquivos = [
      'assets/background/DarkMode/d1.jpg',
      'assets/background/DarkMode/d2.jpg',
      'assets/background/LightMode/l1.jpg',
      'assets/background/LightMode/l2.jpg',
    ];

    setUp(() async {
      pasta = await Directory.systemTemp.createTemp('prep_manager_fundo_test');
      Hive.init(pasta.path);
      await Hive.openBox('settings');
      FundoService.atualEscuro = null;
      FundoService.atualClaro = null;
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await pasta.delete(recursive: true);
    });

    test('cada modo usa as imagens da sua pasta', () async {
      await FundoService.sortear(arquivos);
      expect(FundoService.imagemPara(escuro: true)!.contains('DarkMode'), isTrue);
      expect(FundoService.imagemPara(escuro: false)!.contains('LightMode'), isTrue);
    });

    test('troca a imagem de cada modo a cada abertura', () async {
      await FundoService.sortear(arquivos);
      for (var i = 0; i < 20; i++) {
        final escuroAntes = FundoService.atualEscuro;
        final claroAntes = FundoService.atualClaro;
        await FundoService.sortear(arquivos);
        expect(FundoService.atualEscuro == escuroAntes, isFalse);
        expect(FundoService.atualClaro == claroAntes, isFalse);
      }
    });

    test('pasta de um modo vazia: usa a imagem do outro modo', () async {
      await FundoService.sortear(['assets/background/DarkMode/d1.jpg']);
      expect(FundoService.imagemPara(escuro: false), 'assets/background/DarkMode/d1.jpg');
      expect(FundoService.imagemPara(escuro: true), 'assets/background/DarkMode/d1.jpg');
    });

    test('sem nenhuma imagem, não há fundo', () async {
      await FundoService.sortear(['assets/inicial2.png']);
      expect(FundoService.imagemPara(escuro: true), isNull);
      expect(FundoService.imagemPara(escuro: false), isNull);
    });

    test('liga e desliga o fundo', () async {
      expect(FundoService.ativo, isTrue); // padrão
      await FundoService.definirAtivo(false);
      expect(FundoService.ativo, isFalse);
    });
  });
}