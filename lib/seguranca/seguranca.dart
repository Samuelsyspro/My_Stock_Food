import 'package:flutter/material.dart';
import 'package:prep_manager/seguranca/armazenamento_keystore.dart';
import 'package:prep_manager/seguranca/armazenamento_seguro.dart';
import 'package:prep_manager/seguranca/biometria_service.dart';
import 'package:prep_manager/seguranca/dados_seguros.dart';
import 'package:prep_manager/seguranca/trava_service.dart';

/// Ponto único de acesso aos serviços de segurança do app.
class Seguranca {
  Seguranca._();
  static final Seguranca instancia = Seguranca._();

  final ArmazenamentoSeguro armazenamento = ArmazenamentoKeystore();
  late final TravaService trava = TravaService(armazenamento);
  late final DadosSeguros dados = DadosSeguros(armazenamento);
  final BiometriaService biometria = BiometriaService();

  /// O app está travado? Começa travado a cada abertura.
  final ValueNotifier<bool> bloqueado = ValueNotifier<bool>(true);

  /// Chave do navegador do app (para abrir telas a partir da tela de bloqueio).
  final GlobalKey<NavigatorState> navegador = GlobalKey<NavigatorState>();
}

/// Enquanto o app está travado, o botão "voltar" do Android não pode fechar
/// nem navegar por trás da tela de bloqueio.
///
/// Precisa ser registrado ANTES do runApp, para ser consultado antes do navegador.
class GuardaBotaoVoltar with WidgetsBindingObserver {
  @override
  Future<bool> didPopRoute() async => Seguranca.instancia.bloqueado.value;
}
