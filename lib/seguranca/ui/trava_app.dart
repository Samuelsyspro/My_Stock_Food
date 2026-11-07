import 'package:flutter/material.dart';
import 'package:prep_manager/screens/backup_screen.dart';
import 'package:prep_manager/seguranca/biometria_service.dart';
import 'package:prep_manager/seguranca/controle_trava.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/ui/tela_bloqueio.dart';

/// Envolve o app inteiro (via MaterialApp.builder):
/// - mostra a tela de bloqueio por cima de tudo enquanto o app está travado;
/// - trava de novo quando o app fica um tempo em segundo plano;
/// - cobre a tela quando o app sai de cena (para não aparecer nos "recentes").
class TravaApp extends StatefulWidget {
  final Widget child;

  const TravaApp({super.key, required this.child});

  @override
  State<TravaApp> createState() => _TravaAppState();
}

class _TravaAppState extends State<TravaApp> with WidgetsBindingObserver {
  final _seg = Seguranca.instancia;
  DateTime? _saiuEm;
  bool _cobrir = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Uma tela do próprio sistema (digital, bloqueio do celular) está aberta.
    if (BiometriaService.emAndamento) return;

    switch (estado) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _saiuEm ??= DateTime.now();
        if (!_seg.bloqueado.value) setState(() => _cobrir = true);
        break;
      case AppLifecycleState.resumed:
        _aoVoltar();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _aoVoltar() async {
    final saiu = _saiuEm;
    _saiuEm = null;

    if (saiu != null) {
      final segundos = await _seg.trava.segundosParaTravar();
      if (deveTravarAoVoltar(DateTime.now().difference(saiu), segundos)) {
        _seg.bloqueado.value = true;
      }
    }
    if (mounted) setState(() => _cobrir = false);
  }

  void _desbloquear({bool abrirAjustes = false}) {
    _seg.bloqueado.value = false;
    if (abrirAjustes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seg.navegador.currentState?.push(
          MaterialPageRoute(builder: (_) => const BackupScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _seg.bloqueado,
      builder: (context, bloqueado, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_cobrir && !bloqueado)
              Positioned.fill(
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
            if (bloqueado)
              Positioned.fill(
                child: TelaBloqueio(onDesbloqueado: _desbloquear),
              ),
          ],
        );
      },
    );
  }
}
