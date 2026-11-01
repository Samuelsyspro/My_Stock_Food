import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/models/item.dart';

/// Cria um item de teste; [diasDeHoje] define a validade (0 = hoje).
Item criar({int? diasDeHoje, double quantidade = 1, double? minimo}) {
  final hoje = DateTime.now();
  return Item(
    id: 'x',
    nome: 'Arroz',
    categoria: 'Alimentos',
    quantidade: quantidade,
    unidade: 'kg',
    validade: diasDeHoje == null
        ? null
        : DateTime(hoje.year, hoje.month, hoje.day + diasDeHoje, 14, 30),
    criadoEm: hoje,
    quantidadeMinima: minimo,
  );
}

void main() {
  group('validade', () {
    test('sem validade nunca vence', () {
      final item = criar();
      expect(item.estaVencido, isFalse);
      expect(item.venceEmBreve, isFalse);
      expect(item.diasParaVencer, isNull);
    });

    test('ontem = vencido', () {
      final item = criar(diasDeHoje: -1);
      expect(item.estaVencido, isTrue);
      expect(item.venceEmBreve, isFalse);
    });

    test('hoje NÃO é vencido, mas vence em breve (0 dias)', () {
      final item = criar(diasDeHoje: 0);
      expect(item.estaVencido, isFalse);
      expect(item.venceEmBreve, isTrue);
      expect(item.diasParaVencer, 0);
    });

    test('30 dias ainda vence em breve; 31 não', () {
      expect(criar(diasDeHoje: 30).venceEmBreve, isTrue);
      expect(criar(diasDeHoje: 31).venceEmBreve, isFalse);
    });
  });

  group('estoque mínimo', () {
    test('sem mínimo nunca está abaixo', () {
      expect(criar(quantidade: 0).abaixoDoMinimo, isFalse);
    });

    test('igual ou abaixo do mínimo = true', () {
      expect(criar(quantidade: 3, minimo: 2).abaixoDoMinimo, isFalse);
      expect(criar(quantidade: 2, minimo: 2).abaixoDoMinimo, isTrue);
      expect(criar(quantidade: 1, minimo: 2).abaixoDoMinimo, isTrue);
    });
  });

  group('backup (toMap / fromMap)', () {
    test('ida e volta mantém os dados', () {
      final original = criar(diasDeHoje: 10, quantidade: 2.5, minimo: 1);
      original.localizacao = 'Despensa';
      original.notas = 'Marca X';

      final copia = Item.fromMap(original.toMap());

      expect(copia.id, original.id);
      expect(copia.nome, original.nome);
      expect(copia.categoria, original.categoria);
      expect(copia.quantidade, 2.5);
      expect(copia.unidade, 'kg');
      expect(copia.validade, original.validade);
      expect(copia.localizacao, 'Despensa');
      expect(copia.notas, 'Marca X');
      expect(copia.quantidadeMinima, 1);
    });

    test('campos ausentes recebem valores padrão', () {
      final item = Item.fromMap({'id': 'a', 'nome': 'Sal', 'quantidade': 1});
      expect(item.categoria, 'Outros');
      expect(item.unidade, 'un');
      expect(item.validade, isNull);
    });
  });
}
