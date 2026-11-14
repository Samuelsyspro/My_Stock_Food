import 'package:flutter_test/flutter_test.dart';
import 'package:prep_manager/services/backup_arquivo.dart';

void main() {
  group('BackupArquivo.nomeSugerido', () {
    test('usa data e hora no nome, com extensão .json', () {
      expect(
        BackupArquivo.nomeSugerido(DateTime(2026, 11, 7, 14, 30)),
        'despensa_backup_2026-11-07_1430.json',
      );
    });

    test('completa com zeros (mês, dia, hora e minuto)', () {
      expect(
        BackupArquivo.nomeSugerido(DateTime(2026, 1, 5, 9, 5)),
        'despensa_backup_2026-01-05_0905.json',
      );
    });

    test('meia-noite e fim de ano', () {
      expect(
        BackupArquivo.nomeSugerido(DateTime(2026, 12, 31, 0, 0)),
        'despensa_backup_2026-12-31_0000.json',
      );
    });

    test('sem data, usa o momento atual e continua num formato válido para arquivo', () {
      final nome = BackupArquivo.nomeSugerido();
      expect(
        RegExp(r'^despensa_backup_\d{4}-\d{2}-\d{2}_\d{4}\.json$').hasMatch(nome),
        isTrue,
        reason: nome,
      );
    });
  });
}
