/// Regras simples da trava que não dependem do Flutter (e por isso são testáveis).
library;

/// O app voltou do segundo plano: já passou tempo suficiente para travar de novo?
bool deveTravarAoVoltar(Duration tempoFora, int segundosConfigurados) =>
    tempoFora >= Duration(seconds: segundosConfigurados);

/// Mostra o tempo de espera de forma curta: "0:27", "4:59", "1 h 00 min".
String formatarEspera(Duration espera) {
  final total = espera.inSeconds < 0 ? 0 : espera.inSeconds + (espera.inMilliseconds % 1000 > 0 ? 1 : 0);
  final horas = total ~/ 3600;
  final minutos = (total % 3600) ~/ 60;
  final segundos = total % 60;
  if (horas > 0) {
    return '$horas h ${minutos.toString().padLeft(2, '0')} min';
  }
  return '$minutos:${segundos.toString().padLeft(2, '0')}';
}
