import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prep_manager/screens/menu_screen.dart';
import 'package:prep_manager/services/fundo_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Tempo mínimo mostrando a imagem de abertura (antes eram 3 segundos).
  // Aumente ou diminua aqui, se quiser.
  static const Duration _duracaoMinima = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    // O tempo mínimo e o preparo do fundo acontecem ao mesmo tempo,
    // então o preparo não deixa a abertura mais lenta.
    await Future.wait([
      Future.delayed(_duracaoMinima),
      _prepararFundo(),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MenuScreen()),
    );
  }

  /// Sorteia a imagem de fundo desta abertura (pasta assets/background).
  /// Se algo falhar, o app abre normalmente, só sem imagem.
  Future<void> _prepararFundo() async {
    try {
      final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
      await FundoService.sortear(manifesto.listAssets());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07A35D),
      body: Center(
        child: Image.asset(
          'assets/Inicial2.png', // o nome precisa ser igual ao do arquivo (maiúsculas contam no Android)
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}