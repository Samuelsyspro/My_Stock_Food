import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:prep_manager/seguranca/backup_cripto.dart';
import 'package:prep_manager/seguranca/tela_do_sistema.dart';

/// Salva e abre o arquivo do backup usando a tela de arquivos do próprio
/// sistema, que funciona igual no Android e no iOS:
/// - Android: a pessoa escolhe a pasta (Downloads, Google Drive, cartão...);
/// - iOS: abre o app Arquivos (iCloud Drive, "No meu iPhone", Google Drive...).
///
/// O app não precisa de permissão de armazenamento: o sistema entrega só o
/// arquivo que a pessoa escolheu.
class BackupArquivo {
  BackupArquivo._();

  /// Backups maiores do que isso não são de verdade (proteção contra abrir
  /// por engano um vídeo ou outro arquivo enorme).
  static const int _tamanhoMaximo = 20 * 1024 * 1024;

  /// Nome sugerido: despensa_backup_2026-11-07_1430.json
  static String nomeSugerido([DateTime? quando]) =>
      'despensa_backup_${DateFormat('yyyy-MM-dd_HHmm').format(quando ?? DateTime.now())}.json';

  /// Abre a tela "salvar como" do sistema. Devolve false se a pessoa cancelou.
  static Future<bool> salvar(String texto) async {
    final uri = await TelaDoSistema.enquanto(
      () => FilePicker.saveFile(
        dialogTitle: 'Salvar backup protegido',
        fileName: nomeSugerido(),
        bytes: Uint8List.fromList(utf8.encode(texto)),
        mimeType: 'application/json',
      ),
    );
    return uri != null;
  }

  /// Abre a tela de escolher arquivo do sistema e devolve o texto do backup
  /// (ou null se a pessoa cancelou).
  static Future<String?> abrir() async {
    final arquivo = await TelaDoSistema.enquanto(
      // "any": alguns apps (Drive, WhatsApp) trocam o tipo do arquivo, e o
      // filtro por .json acabaria escondendo o backup. O conteúdo é conferido
      // logo abaixo.
      () => FilePicker.pickFile(
        dialogTitle: 'Escolha o arquivo do backup',
        type: FileType.any,
      ),
    );
    if (arquivo == null) return null;

    final tamanho = await arquivo.length();
    if (tamanho != null && tamanho > _tamanhoMaximo) {
      throw const BackupException('Esse arquivo é grande demais para ser um backup.');
    }

    final String texto;
    try {
      texto = utf8.decode(await arquivo.readAsBytes());
    } on FormatException {
      throw const BackupException('Esse arquivo não é um backup do app.');
    }

    // Aceita também backups antigos (sem proteção), que são JSON com os itens.
    if (!BackupProtegido.ehProtegido(texto) && !_pareceJson(texto)) {
      throw const BackupException('Esse arquivo não é um backup do app.');
    }
    return texto;
  }

  static bool _pareceJson(String texto) {
    try {
      jsonDecode(texto);
      return true;
    } catch (_) {
      return false;
    }
  }
}
