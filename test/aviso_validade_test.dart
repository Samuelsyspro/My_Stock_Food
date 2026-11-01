import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/services/aviso_validade.dart';

Item criar(String nome, DateTime? validade, {double quantidade = 1}) => Item(
      id: nome,
      nome: nome,
      categoria: 'Alimentos',
      quantidade: quantidade,
      unidade: 'un',
      validade: validade,
      criadoEm: DateTime(2026, 1, 1),
    );

void main() {
  // "Hoje" fixo para o teste: 10/11/2026 às 08:00
  final agora = DateTime(2026, 11, 10, 8, 0);

  test('item que vence daqui a 30 dias gera 2 avisos (7 dias antes e no dia)', () {
    final avisos = planejarAvisos(
      [criar('Leite', DateTime(2026, 12, 10))],
      agora: agora,
    );

    expect(avisos.length, 2);
    expect(avisos[0].quando, DateTime(2026, 12, 3, 9, 0));
    expect(avisos[0].titulo, 'Vence em 7 dias');
    expect(avisos[0].corpo, 'Leite');
    expect(avisos[1].quando, DateTime(2026, 12, 10, 9, 0));
    expect(avisos[1].titulo, 'Vence hoje');
  });

  test('itens da mesma data viram um aviso só', () {
    final avisos = planejarAvisos([
      criar('Pão', DateTime(2026, 12, 10)),
      criar('Água', DateTime(2026, 12, 10)),
      criar('Leite', DateTime(2026, 12, 10)),
    ], agora: agora);

    final hoje = avisos.last;
    expect(hoje.titulo, '3 itens vencem hoje');
    expect(hoje.corpo, 'Água, Leite, Pão');
    expect(avisos.length, 2);
  });

  test('lista longa de nomes é resumida', () {
    final itens = [
      for (final n in ['A', 'B', 'C', 'D', 'E', 'F'])
        criar(n, DateTime(2026, 12, 10)),
    ];
    final avisos = planejarAvisos(itens, agora: agora);
    expect(avisos.last.corpo, 'A, B, C, D e mais 2');
  });

  test('não cria avisos no passado', () {
    // Vence amanhã: o aviso de "7 dias antes" já passou, só sobra o do dia
    final avisos = planejarAvisos(
      [criar('Iogurte', DateTime(2026, 11, 11))],
      agora: agora,
    );
    expect(avisos.length, 1);
    expect(avisos.single.titulo, 'Vence hoje');
    expect(avisos.single.quando, DateTime(2026, 11, 11, 9, 0));
  });

  test('item que vence hoje depois das 9h não gera aviso; antes das 9h gera', () {
    final item = criar('Queijo', DateTime(2026, 11, 10));
    expect(planejarAvisos([item], agora: DateTime(2026, 11, 10, 10)), isEmpty);
    expect(planejarAvisos([item], agora: DateTime(2026, 11, 10, 8)).length, 1);
  });

  test('ignora item sem validade, já vencido ou com quantidade zero', () {
    final avisos = planejarAvisos([
      criar('Sal', null),
      criar('Velho', DateTime(2026, 10, 1)),
      criar('Acabou', DateTime(2026, 12, 10), quantidade: 0),
    ], agora: agora);
    expect(avisos, isEmpty);
  });

  test('ignora validades além do horizonte', () {
    final avisos = planejarAvisos(
      [criar('Conserva', DateTime(2030, 1, 1))],
      agora: agora,
    );
    expect(avisos, isEmpty);
  });

  test('ids são únicos e estáveis', () {
    final itens = [
      criar('A', DateTime(2026, 12, 10)),
      criar('B', DateTime(2026, 12, 20)),
    ];
    final ids = planejarAvisos(itens, agora: agora).map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(planejarAvisos(itens, agora: agora).map((a) => a.id).toList(), ids);
  });
}
