import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/utils/helpers.dart';

/// Resultado de uma restauração de backup.
class ResultadoImportacao {
  final int itensAdicionados;
  final int itensAtualizados;
  final int comprasAdicionadas;
  final int ignorados;

  const ResultadoImportacao({
    required this.itensAdicionados,
    required this.itensAtualizados,
    required this.comprasAdicionadas,
    required this.ignorados,
  });
}

/// Exporta e restaura os dados (Dispensa + Lista de Compras) como texto JSON.
class BackupService {
  Box<Item> get _itens => Hive.box<Item>('items');
  Box<ShoppingItem> get _compras => Hive.box<ShoppingItem>('shopping_list');

  /// Gera o texto do backup com tudo que está salvo no app.
  String exportar() {
    final dados = <String, dynamic>{
      'app': 'prep_manager',
      'versao': 1,
      'geradoEm': DateTime.now().toIso8601String(),
      'itens': _itens.values.map((i) => i.toMap()).toList(),
      'compras': _compras.values.map((c) => c.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(dados);
  }

  /// Restaura um backup. Não apaga nada do que já existe:
  /// - item com o mesmo id é atualizado; os demais são adicionados;
  /// - compra igual (nome, categoria e unidade) não é duplicada.
  /// Lança [FormatException] se o texto não for um backup válido.
  Future<ResultadoImportacao> importar(String texto) async {
    Object? decodificado;
    try {
      decodificado = jsonDecode(texto);
    } catch (_) {
      throw const FormatException('O texto não é um backup válido.');
    }
    if (decodificado is! Map || decodificado['app'] != 'prep_manager') {
      throw const FormatException('Esse texto não é um backup do Dispensa Digital.');
    }

    var adicionados = 0;
    var atualizados = 0;
    var compras = 0;
    var ignorados = 0;

    final listaItens = decodificado['itens'];
    if (listaItens is List) {
      for (final bruto in listaItens) {
        try {
          final novo = Item.fromMap(Map<String, dynamic>.from(bruto as Map));

          dynamic chave;
          for (final k in _itens.keys) {
            if (_itens.get(k)?.id == novo.id) {
              chave = k;
              break;
            }
          }

          if (chave != null) {
            await _itens.put(chave, novo);
            atualizados++;
          } else {
            await _itens.put(novo.id, novo);
            adicionados++;
          }
        } catch (_) {
          ignorados++;
        }
      }
    }

    final listaCompras = decodificado['compras'];
    if (listaCompras is List) {
      for (final bruto in listaCompras) {
        try {
          final nova =
              ShoppingItem.fromMap(Map<String, dynamic>.from(bruto as Map));

          final jaExiste = _compras.values.any((c) =>
              normalizar(c.name) == normalizar(nova.name) &&
              normalizar(c.categoria) == normalizar(nova.categoria) &&
              normalizar(c.unidade) == normalizar(nova.unidade));

          if (!jaExiste) {
            await _compras.add(nova);
            compras++;
          }
        } catch (_) {
          ignorados++;
        }
      }
    }

    return ResultadoImportacao(
      itensAdicionados: adicionados,
      itensAtualizados: atualizados,
      comprasAdicionadas: compras,
      ignorados: ignorados,
    );
  }
}
