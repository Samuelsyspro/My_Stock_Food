import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Digital, rosto e bloqueio de tela do celular (PIN, padrão ou senha do aparelho).
class BiometriaService {
  /// Enquanto for true, o app está mostrando uma tela do sistema (digital, rosto
  /// ou bloqueio do celular). Mudanças de "primeiro/segundo plano" nesse momento
  /// são normais e NÃO devem travar o app.
  static bool emAndamento = false;

  final LocalAuthentication _auth = LocalAuthentication();

  /// O celular tem digital ou rosto cadastrados?
  Future<bool> get biometriaDisponivel async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final tipos = await _auth.getAvailableBiometrics();
      return tipos.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// O celular tem algum bloqueio de tela (PIN, padrão, senha, digital ou rosto)?
  Future<bool> get bloqueioDoCelularDisponivel async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Só digital ou rosto (não aceita o PIN do aparelho).
  Future<bool> autenticarBiometria(String motivo) =>
      _autenticar(motivo, apenasBiometria: true);

  /// Digital, rosto OU o PIN/padrão/senha do aparelho.
  Future<bool> autenticarComBloqueioDoCelular(String motivo) =>
      _autenticar(motivo, apenasBiometria: false);

  Future<bool> _autenticar(String motivo, {required bool apenasBiometria}) async {
    emAndamento = true;
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: AuthenticationOptions(
          biometricOnly: apenasBiometria,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } finally {
      // Espera um pouco: o aviso de "voltou ao primeiro plano" pode chegar
      // logo depois da resposta da tela do sistema.
      Future.delayed(const Duration(seconds: 1), () => emAndamento = false);
    }
  }
}
