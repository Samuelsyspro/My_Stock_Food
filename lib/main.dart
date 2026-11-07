import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/screens/splash_screen.dart';
import 'package:prep_manager/seguranca/dados_seguros.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/tela_erro_dados.dart';
import 'package:prep_manager/seguranca/ui/trava_app.dart';
import 'package:prep_manager/services/notification_service.dart';

void main() async {
  // 1. Inicializa o Flutter (apenas uma vez)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Segura a splash nativa do Android
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

  // 3. Inicializa o Hive e os modelos
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(ShoppingItemAdapter());

  // 4. Enquanto o app estiver travado, o botão "voltar" não pode navegar por
  //    trás da tela de bloqueio. Precisa ser registrado antes do runApp.
  WidgetsBinding.instance.addObserver(GuardaBotaoVoltar());

  // 5. Abre os dados (criptografados) e inicia o app
  await _iniciarApp();

  // 6. Libera a splash nativa (a tela do Flutter já está pronta)
  FlutterNativeSplash.remove();
}

/// Abre as caixas criptografadas do Hive (migrando dados antigos, se houver)
/// e inicia o app. Se os dados não puderem ser lidos, mostra uma tela com
/// opções, sem nunca apagar nada sozinho.
Future<void> _iniciarApp({bool recuperar = false}) async {
  try {
    await Seguranca.instancia.dados.iniciar(recuperar: recuperar);
  } on ChaveDadosPerdida catch (erro) {
    _mostrarErroDados(erro);
    return;
  } on DadosIlegiveis catch (erro) {
    _mostrarErroDados(erro);
    return;
  }

  // O app sempre começa travado: pede o PIN (ou cria um, no primeiro uso).
  Seguranca.instancia.bloqueado.value = true;
  runApp(const PrepManagerApp());

  // Avisos de validade (sem esperar: se falhar, o app segue normal)
  unawaited(NotificationService.instance.iniciar());
}

void _mostrarErroDados(Object erro) {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _montarTema(Brightness.light),
      darkTheme: _montarTema(Brightness.dark),
      themeMode: ThemeMode.system,
      home: TelaErroDados(
        erro: erro,
        onTentar: ({required bool recuperar}) => _iniciarApp(recuperar: recuperar),
        onApagar: () async {
          await Seguranca.instancia.dados.apagarTudo();
          await _iniciarApp();
        },
      ),
    ),
  );
}

ThemeData _montarTema(Brightness brilho) {
  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: brilho,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      // Transparente: deixa a imagem de fundo aparecer atrás da barra
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class PrepManagerApp extends StatelessWidget {
  const PrepManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dispensa Digital',
      color: const Color(0xFF07A35D),
      debugShowCheckedModeBanner: false,
      navigatorKey: Seguranca.instancia.navegador,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Segue o modo do celular: claro ou escuro
      theme: _montarTema(Brightness.light),
      darkTheme: _montarTema(Brightness.dark),
      themeMode: ThemeMode.system,
      // A trava cobre o app inteiro (todas as telas)
      builder: (context, child) => TravaApp(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(), // Inicia na SplashScreen
    );
  }
}
