import 'dart:math';

import 'package:hive/hive.dart';

/// Imagem de fundo do app. Há duas pastas: uma para o modo escuro do celular
/// e outra para o modo claro. A cada vez que o app é aberto, é sorteada uma
/// imagem de cada pasta (sem repetir a da vez anterior).
class FundoService {
  // Em minúsculas de propósito: a comparação ignora maiúsculas, então
  // "DarkMode", "darkmode" e "DARKMODE" funcionam.
  static const String pastaEscuro = 'assets/background/darkmode/';
  static const String pastaClaro = 'assets/background/lightmode/';

  static const String chaveAtivo = 'fundo_ativo';
  static const String _chaveUltimaEscuro = 'ultimo_fundo_escuro';
  static const String _chaveUltimaClaro = 'ultimo_fundo_claro';
  // .jfif é um JPEG comum (alguns programas salvam assim)
  static const List<String> _extensoes = ['.png', '.jpg', '.jpeg', '.jfif', '.webp'];

  /// Imagens sorteadas nesta abertura do app (null = pasta sem imagens).
  static String? atualEscuro;
  static String? atualClaro;

  static Box get _config => Hive.box('settings');

  /// Fundo ligado? (padrão: sim)
  static bool get ativo => _config.get(chaveAtivo, defaultValue: true) as bool;

  static Future<void> definirAtivo(bool valor) => _config.put(chaveAtivo, valor);

  /// Imagem para o modo atual do celular. Se a pasta desse modo estiver
  /// vazia, usa a do outro modo (melhor do que ficar sem imagem).
  static String? imagemPara({required bool escuro}) =>
      escuro ? (atualEscuro ?? atualClaro) : (atualClaro ?? atualEscuro);

  /// Das listas de arquivos do app, fica só com as imagens da [pasta]
  /// (sem diferenciar maiúsculas de minúsculas no nome da pasta).
  static List<String> filtrarImagens(Iterable<String> arquivos, String pasta) {
    final imagens = arquivos.where((caminho) {
      final minusculo = caminho.toLowerCase();
      return minusculo.startsWith(pasta) &&
          _extensoes.any((ext) => minusculo.endsWith(ext));
    }).toList();
    imagens.sort();
    return imagens;
  }

  /// Escolhe uma imagem ao acaso, diferente da [ultima] (quando há mais de uma).
  static String? escolher(
    List<String> imagens, {
    String? ultima,
    Random? random,
  }) {
    if (imagens.isEmpty) return null;
    if (imagens.length == 1) return imagens.first;

    final candidatas = imagens.where((i) => i != ultima).toList();
    final lista = candidatas.isEmpty ? imagens : candidatas;
    return lista[(random ?? Random()).nextInt(lista.length)];
  }

  /// Sorteia as imagens desta abertura (uma por modo) e lembra quais foram.
  static Future<void> sortear(Iterable<String> arquivos, {Random? random}) async {
    final lista = arquivos.toList();

    atualEscuro = escolher(
      filtrarImagens(lista, pastaEscuro),
      ultima: _config.get(_chaveUltimaEscuro) as String?,
      random: random,
    );
    atualClaro = escolher(
      filtrarImagens(lista, pastaClaro),
      ultima: _config.get(_chaveUltimaClaro) as String?,
      random: random,
    );

    if (atualEscuro != null) await _config.put(_chaveUltimaEscuro, atualEscuro);
    if (atualClaro != null) await _config.put(_chaveUltimaClaro, atualClaro);
  }
}