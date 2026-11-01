import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/services/aviso_validade.dart';
import 'package:timezone/timezone.dart' as tz;

/// Avisos de validade (notificações do celular).
///
/// Os avisos são agendados no próprio Android, então chegam mesmo com o app
/// fechado e continuam depois de reiniciar o celular. Sempre que um item muda,
/// a agenda inteira é refeita.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _chaveAtivado = 'avisos_validade';
  static const _chavePermissaoPedida = 'permissao_avisos_pedida';

  static const _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'validade',
      'Avisos de validade',
      channelDescription: 'Avisa quando itens estão perto de vencer',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _pronto = false;
  bool _reagendando = false;
  bool _pendente = false;
  Timer? _timer;

  Box get _config => Hive.box('settings');

  /// Avisos ligados? (padrão: sim)
  bool get ativado => _config.get(_chaveAtivado, defaultValue: true) as bool;

  /// Prepara o plugin. Se algo falhar, o app continua funcionando sem avisos.
  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );
      _pronto = true;
    } catch (e) {
      debugPrint('Avisos indisponíveis: $e');
    }
  }

  /// Chamado uma vez ao abrir o app: prepara, pede permissão na primeira vez,
  /// agenda e passa a acompanhar mudanças nos itens.
  Future<void> iniciar() async {
    await init();
    if (!_pronto) return;

    final jaPediu = _config.get(_chavePermissaoPedida, defaultValue: false) as bool;
    if (ativado && !jaPediu) {
      await _config.put(_chavePermissaoPedida, true);
      final concedida = await pedirPermissao();
      if (!concedida) await _config.put(_chaveAtivado, false);
    }

    await reagendar();
    Hive.box<Item>('items').watch().listen((_) => _agendarAtualizacao());
  }

  /// Pede a permissão de notificações (Android 13 ou mais novo).
  Future<bool> pedirPermissao() async {
    if (!_pronto) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final concedida = await android?.requestNotificationsPermission();
    return concedida ?? false;
  }

  /// Liga ou desliga os avisos. Devolve o estado final
  /// (fica desligado se a permissão for negada).
  Future<bool> definirAtivado(bool valor) async {
    if (valor) {
      final concedida = await pedirPermissao();
      if (!concedida) {
        await _config.put(_chaveAtivado, false);
        return false;
      }
    }
    await _config.put(_chaveAtivado, valor);
    await reagendar();
    return valor;
  }

  /// Mostra um aviso na hora, para conferir se está tudo funcionando.
  Future<void> enviarTeste() async {
    if (!_pronto) return;
    await _plugin.show(
      0,
      'Dispensa Digital',
      'Os avisos de validade estão funcionando!',
      _detalhes,
    );
  }

  // Espera 2 segundos sem mudanças antes de refazer a agenda
  // (assim, apertar + e − várias vezes não refaz tudo a cada toque).
  void _agendarAtualizacao() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), reagendar);
  }

  /// Apaga os avisos agendados e cria de novo, de acordo com os itens atuais.
  Future<void> reagendar() async {
    if (!_pronto) return;
    if (_reagendando) {
      _pendente = true;
      return;
    }

    _reagendando = true;
    try {
      do {
        _pendente = false;
        await _plugin.cancelAll();

        if (ativado) {
          final itens = Hive.box<Item>('items').values.toList();
          for (final aviso in planejarAvisos(itens)) {
            await _plugin.zonedSchedule(
              aviso.id,
              aviso.titulo,
              aviso.corpo,
              // O horário já é um instante exato; UTC evita depender do fuso.
              tz.TZDateTime.fromMillisecondsSinceEpoch(
                tz.UTC,
                aviso.quando.millisecondsSinceEpoch,
              ),
              _detalhes,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        }
      } while (_pendente);
    } catch (e) {
      debugPrint('Erro ao agendar avisos: $e');
    } finally {
      _reagendando = false;
    }
  }
}
