import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/utils/helpers.dart';

/// Um aviso já calculado (sem depender do Flutter, por isso é fácil de testar).
class AvisoPlanejado {
  final int id;
  final DateTime quando;
  final String titulo;
  final String corpo;

  const AvisoPlanejado({
    required this.id,
    required this.quando,
    required this.titulo,
    required this.corpo,
  });
}

/// Calcula os avisos de validade dos itens.
///
/// Para cada data de vencimento são criados no máximo 2 avisos, juntando todos
/// os itens da mesma data (assim o celular não recebe 20 avisos de uma vez):
/// - [diasAntes] dias antes do vencimento: "Vence em 7 dias"
/// - no dia do vencimento: "Vence hoje"
///
/// Só entram itens com validade e quantidade maior que zero, e só avisos que
/// ainda vão acontecer (depois de [agora]) dentro de [horizonteDias].
List<AvisoPlanejado> planejarAvisos(
  Iterable<Item> itens, {
  DateTime? agora,
  int diasAntes = 7,
  int hora = 9,
  int horizonteDias = 365,
}) {
  final instanteAtual = agora ?? DateTime.now();
  final limite = DateTime(
    instanteAtual.year,
    instanteAtual.month,
    instanteAtual.day + horizonteDias,
  );

  // chave do aviso -> momento e nomes dos itens
  final noDia = <int, _Grupo>{};
  final antes = <int, _Grupo>{};

  for (final item in itens) {
    final validade = item.validade;
    if (validade == null || item.quantidade <= 0) continue;

    final dia = somenteData(validade);

    void registrar(Map<int, _Grupo> grupos, DateTime quando) {
      if (!quando.isAfter(instanteAtual) || quando.isAfter(limite)) return;
      final chave = quando.year * 10000 + quando.month * 100 + quando.day;
      grupos.putIfAbsent(chave, () => _Grupo(quando)).nomes.add(item.nome);
    }

    registrar(noDia, DateTime(dia.year, dia.month, dia.day, hora));
    registrar(antes, DateTime(dia.year, dia.month, dia.day - diasAntes, hora));
  }

  final avisos = <AvisoPlanejado>[];

  noDia.forEach((chave, grupo) {
    avisos.add(AvisoPlanejado(
      id: chave * 2, // número par = "vence hoje"
      quando: grupo.quando,
      titulo: grupo.nomes.length == 1
          ? 'Vence hoje'
          : '${grupo.nomes.length} itens vencem hoje',
      corpo: _resumirNomes(grupo.nomes),
    ));
  });

  antes.forEach((chave, grupo) {
    avisos.add(AvisoPlanejado(
      id: chave * 2 + 1, // número ímpar = "vence em breve"
      quando: grupo.quando,
      titulo: grupo.nomes.length == 1
          ? 'Vence em $diasAntes dias'
          : '${grupo.nomes.length} itens vencem em $diasAntes dias',
      corpo: _resumirNomes(grupo.nomes),
    ));
  });

  avisos.sort((a, b) => a.quando.compareTo(b.quando));
  return avisos;
}

class _Grupo {
  final DateTime quando;
  final List<String> nomes = [];
  _Grupo(this.quando);
}

/// "Arroz, Feijão e mais 3" (mostra no máximo 4 nomes).
String _resumirNomes(List<String> nomes) {
  final ordenados = [...nomes]
    ..sort((a, b) => normalizar(a).compareTo(normalizar(b)));
  if (ordenados.length <= 4) return ordenados.join(', ');
  final resto = ordenados.length - 4;
  return '${ordenados.take(4).join(', ')} e mais $resto';
}
