import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/models/shopping_item.dart';
import 'package:prep_manager/screens/splash_screen.dart';
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

  // 4. Abre as caixas (as três ao mesmo tempo, para abrir mais rápido)
  await Future.wait([
    Hive.openBox<Item>('items'),
    Hive.openBox<ShoppingItem>('shopping_list'),
    Hive.openBox('settings'), // ajustes simples (ex.: avisos ligados)
  ]);

  // (a imagem de fundo é sorteada na SplashScreen, enquanto a imagem de
  //  abertura aparece: assim a splash do Android sai da tela mais cedo)

  // 5. Inicia o app
  runApp(const PrepManagerApp());

  // Avisos de validade (sem esperar: se falhar, o app segue normal)
  unawaited(NotificationService.instance.iniciar());
  
  // 6. Libera a splash nativa (a tela do Flutter já está pronta)
  FlutterNativeSplash.remove();
}

class PrepManagerApp extends StatelessWidget {
  const PrepManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dispensa Digital',
      color: const Color(0xFF07A35D),
      debugShowCheckedModeBanner: false,
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
      home: const SplashScreen(), // Inicia na SplashScreen
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
}