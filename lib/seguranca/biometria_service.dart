import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:prep_manager/seguranca/tela_do_sistema.dart';

/// Digital, rosto e bloqueio de tela do celular (PIN, padrão ou senha do aparelho).
class BiometriaService {
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

  /// A tela da digital/rosto é do sistema: enquanto ela está aberta, o app
  /// não deve travar (veja [TelaDoSistema]).
  Future<bool> _autenticar(String motivo, {required bool apenasBiometria}) =>
      TelaDoSistema.enquanto(() async {
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
        }
      });
}
