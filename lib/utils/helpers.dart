/// Funções pequenas e reaproveitáveis (sem depender do Flutter).

/// Deixa o texto minúsculo, sem acentos e sem espaços nas pontas.
/// Serve para comparar nomes: "Água " e "agua" viram o mesmo texto.
String normalizar(String texto) {
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const semAcento = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

  final buffer = StringBuffer();
  for (final rune in texto.trim().runes) {
    final caractere = String.fromCharCode(rune);
    final i = comAcento.indexOf(caractere);
    buffer.write(i >= 0 ? semAcento[i] : caractere);
  }
  return buffer.toString().toLowerCase();
}

/// Mostra a quantidade sem ".0" quando for inteira.
/// 1.0 -> "1", 1.5 -> "1,5", 0.25 -> "0,25"
String formatarQuantidade(double valor) {
  if (valor == valor.truncateToDouble()) return valor.toStringAsFixed(0);

  var texto = valor.toStringAsFixed(2);
  texto = texto.replaceAll(RegExp(r'0+$'), '');
  texto = texto.replaceAll(RegExp(r'\.$'), '');
  return texto.replaceAll('.', ',');
}

/// Mantém só o dia (ano, mês e dia), ignorando a hora.
/// Usa UTC de propósito: assim a conta de dias não erra no horário de verão.
DateTime somenteData(DateTime data) =>
    DateTime.utc(data.year, data.month, data.day);
