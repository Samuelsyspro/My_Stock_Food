import 'package:flutter/material.dart';
import 'package:prep_manager/screens/menu_screen.dart';

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
    // A imagem de fundo já foi sorteada no main.dart, antes do app abrir.
    await Future.delayed(_duracaoMinima);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MenuScreen()),
    );
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