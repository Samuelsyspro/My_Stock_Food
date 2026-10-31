import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'models/item.dart';
import 'models/shopping_item.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Inicializa o Flutter (apenas uma vez)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Segura a splash nativa do Android
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);

  // 3. Inicializa o Hive e os modelos
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(ShoppingItemAdapter());

  // 4. Abre as caixas
  await Hive.openBox<Item>('items');
  await Hive.openBox<ShoppingItem>('shopping_list');

  // 5. Inicia o app
  runApp(const PrepManagerApp());
  
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(), // Inicia na SplashScreen
    );
  }
}