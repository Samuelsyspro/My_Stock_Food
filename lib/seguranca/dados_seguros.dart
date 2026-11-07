import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/seguranca/armazenamento_seguro.dart';

/// A chave dos dados sumiu (por exemplo, o app foi restaurado de um backup do
/// Android em outro celular). Os dados antigos não podem mais ser lidos.
class ChaveDadosPerdida implements Exception {
  const ChaveDadosPerdida();

  @override
  String toString() => 'A chave de criptografia dos dados não foi encontrada.';
}

/// Os arquivos de dados existem, mas não foi possível abri-los.
class DadosIlegiveis implements Exception {
  final Object causa;
  const DadosIlegiveis(this.causa);

  @override
  String toString() => 'Não foi possível ler os dados: $causa';
}

/// Criptografia dos dados do app (as caixas do Hive).
///
/// - Uma chave aleatória de 256 bits é criada uma vez e guardada no cofre do
///   Android (Keystore), nunca junto dos dados.
/// - As caixas são abertas com essa chave (AES-256 do Hive).
/// - Dados antigos, sem criptografia, são copiados para caixas criptografadas
///   na primeira abertura, de um jeito que aguenta o app ser fechado no meio.
class DadosSeguros {
  static const List<String> nomesCaixas = ['items', 'shopping_list', 'settings'];

  static const String _kChave = 'hive_chave';
  static const String _kFlag = 'dados_criptografados_v1';

  // Estado da migração de cada caixa, guardado no armazenamento seguro:
  //   (vazio)  -> a caixa original ainda é a de antes, sem criptografia
  //   'tmp'    -> a cópia criptografada temporária está completa e confirmada
  //   'final'  -> a caixa definitiva criptografada está pronta
  // Assim nunca precisamos "tentar abrir para descobrir" o tipo de uma caixa.
  static String _kEstado(String nome) => 'migracao_$nome';

  final ArmazenamentoSeguro _st;

  DadosSeguros(this._st);

  // Cada tipo de caixa precisa de uma cópia "nova" dos objetos: um objeto do
  // Hive não pode ser guardado em duas caixas diferentes.
  static dynamic _copiarItem(dynamic v) => v is Item ? Item.fromMap(v.toMap()) : v;
  static dynamic _copiarCompra(dynamic v) =>
      v is ShoppingItem ? ShoppingItem.fromMap(v.toMap()) : v;
  static dynamic _identidade(dynamic v) => v;

  static final Map<String, dynamic Function(dynamic)> _copiadores = {
    'items': _copiarItem,
    'shopping_list': _copiarCompra,
    'settings': _identidade,
  };

  /// Prepara a chave, migra dados antigos (se houver) e abre as caixas.
  /// Lança [ChaveDadosPerdida] ou [DadosIlegiveis] se os dados não puderem ser lidos.
  ///
  /// Por segurança, o padrão é NUNCA cortar um arquivo que não conseguimos ler
  /// (o Hive faria isso sozinho e, com a chave errada, apagaria os dados).
  /// Com [recuperar] = true, o Hive remove só o trecho danificado do final do
  /// arquivo (útil quando o celular desligou no meio de uma gravação).
  Future<void> iniciar({bool recuperar = false}) async {
    final jaMigrado = (await _st.ler(_kFlag)) == '1' || await _temEstadoGravado();
    final chaveTexto = await _st.ler(_kChave);

    if (jaMigrado && chaveTexto == null) throw const ChaveDadosPerdida();

    final List<int> chave;
    if (chaveTexto != null) {
      chave = base64Decode(chaveTexto);
      if (chave.length != 32) throw const ChaveDadosPerdida();
    } else {
      chave = Hive.generateSecureKey();
      await _st.gravar(_kChave, base64Encode(chave));
    }
    final cifra = HiveAesCipher(chave);

    if ((await _st.ler(_kFlag)) != '1') {
      for (final nome in nomesCaixas) {
        await migrarCaixa(nome, cifra);
      }
      await _st.gravar(_kFlag, '1');
    }

    try {
      await _semRuido(() => Future.wait([
            Hive.openBox<Item>('items',
                encryptionCipher: cifra, crashRecovery: recuperar),
            Hive.openBox<ShoppingItem>('shopping_list',
                encryptionCipher: cifra, crashRecovery: recuperar),
            Hive.openBox('settings',
                encryptionCipher: cifra, crashRecovery: recuperar),
          ]));
    } catch (e) {
      await Hive.close();
      throw DadosIlegiveis(e);
    }
  }

  Future<bool> _temEstadoGravado() async {
    for (final nome in nomesCaixas) {
      if ((await _st.ler(_kEstado(nome))) != null) return true;
    }
    return false;
  }

  /// O Hive 2.2.3 avisa um erro de abertura duas vezes: uma para quem chamou
  /// (que tratamos) e outra "solta", que ninguém recebe e que chegaria como um
  /// erro não tratado. Esta função recebe só essa segunda cópia e a descarta.
  Future<T> _semRuido<T>(Future<T> Function() acao) {
    final resposta = Completer<T>();
    runZonedGuarded(() async {
      try {
        resposta.complete(await acao());
      } catch (e, s) {
        resposta.completeError(e, s);
      }
    }, (erro, pilha) {
      // erro duplicado do Hive: o original já foi entregue acima
    });
    return resposta.future;
  }

  /// Apaga todos os dados e a chave (usado quando os dados ficaram ilegíveis
  /// e o usuário escolhe recomeçar ou restaurar um backup).
  Future<void> apagarTudo() async {
    await Hive.close();
    for (final nome in nomesCaixas) {
      await Hive.deleteBoxFromDisk(nome);
      await Hive.deleteBoxFromDisk('${nome}__tmp');
    }
    await _st.apagar(_kChave);
    await _st.apagar(_kFlag);
    for (final nome in nomesCaixas) {
      await _st.apagar(_kEstado(nome));
    }
  }

  /// Copia uma caixa sem criptografia para uma caixa criptografada, mantendo as chaves.
  ///
  /// Ordem (se o app fechar em qualquer ponto, a próxima abertura continua de onde parou):
  /// 1. lê tudo da caixa antiga;
  /// 2. grava uma cópia criptografada temporária e só então marca o estado "tmp";
  /// 3. apaga a caixa antiga e cria a definitiva a partir da cópia;
  /// 4. apaga a temporária e marca o estado "final".
  /// (Público para poder ser testado.)
  Future<void> migrarCaixa(String nome, HiveCipher cifra) async {
    final copiar = _copiadores[nome]!;
    final tmpNome = '${nome}__tmp';
    final estado = await _st.ler(_kEstado(nome));

    // Já está pronta.
    if (estado == 'final') return;

    // A cópia temporária estava completa: termina o serviço a partir dela.
    if (estado == 'tmp') {
      final Map<dynamic, dynamic> dados;
      try {
        dados = await _semRuido(() async {
          final tmp = await Hive.openBox(tmpNome,
              encryptionCipher: cifra, crashRecovery: false);
          final lidos = Map<dynamic, dynamic>.from(tmp.toMap());
          await tmp.close();
          return lidos;
        });
      } catch (e) {
        throw DadosIlegiveis(e);
      }
      await _gravarDefinitiva(nome, dados, cifra, copiar);
      await Hive.deleteBoxFromDisk(tmpNome);
      await _st.gravar(_kEstado(nome), 'final');
      return;
    }

    // Estado vazio: qualquer cópia temporária que exista é de uma tentativa
    // incompleta. Apagamos SEM abrir (abrir uma caixa quebrada é o que dá problema).
    await Hive.deleteBoxFromDisk(tmpNome);

    if (!await Hive.boxExists(nome)) {
      await _st.gravar(_kEstado(nome), 'final'); // instalação nova: nada a migrar
      return;
    }

    // Lê a caixa original. crashRecovery: false => nunca "conserta" cortando o arquivo.
    final Map<dynamic, dynamic> dados;
    try {
      dados = await _semRuido(() async {
        final antiga = await Hive.openBox(nome, crashRecovery: false);
        final lidos = Map<dynamic, dynamic>.from(antiga.toMap());
        await antiga.close();
        return lidos;
      });
    } catch (e) {
      throw DadosIlegiveis(e);
    }

    final tmp = await Hive.openBox(tmpNome, encryptionCipher: cifra);
    await tmp.putAll({for (final e in dados.entries) e.key: copiar(e.value)});
    await tmp.close();
    await _st.gravar(_kEstado(nome), 'tmp');

    await _gravarDefinitiva(nome, dados, cifra, copiar);
    await Hive.deleteBoxFromDisk(tmpNome);
    await _st.gravar(_kEstado(nome), 'final');
  }

  Future<void> _gravarDefinitiva(
    String nome,
    Map<dynamic, dynamic> dados,
    HiveCipher cifra,
    dynamic Function(dynamic) copiar,
  ) async {
    if (await Hive.boxExists(nome)) await Hive.deleteBoxFromDisk(nome);
    final caixa = await Hive.openBox(nome, encryptionCipher: cifra);
    await caixa.putAll({for (final e in dados.entries) e.key: copiar(e.value)});
    await caixa.close();
  }
}
