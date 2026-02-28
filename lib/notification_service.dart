import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// 1. Instância centralizada do Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 2. Definição dos Canais
const AndroidNotificationChannel channelMedicamentos = AndroidNotificationChannel(
  'lembrete_medicamento_channel',
  'Lembretes Críticos de Medicamentos',
  description: 'Canal para alertas urgentes sobre medicamentos.',
  importance: Importance.max,
  playSound: true,
);

const AndroidNotificationChannel channelCompromissos = AndroidNotificationChannel(
  'lembrete_compromisso_channel',
  'Lembretes de Compromissos',
  description: 'Canal para lembretes de exames e consultas.',
  importance: Importance.high,
  playSound: true,
);

// 4. Função de Inicialização Reutilizável
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Cria os canais de notificação no Android
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channelMedicamentos);
  await androidPlugin?.createNotificationChannel(channelCompromissos);
}

// 3. Função de Callback para o AlarmManager
@pragma('vm:entry-point')
Future<void> dispararAlarme() async {
  // Garante que os plugins estão inicializados no isolate de background
  await initializeNotifications();

  final DateTime agora = DateTime.now();
  debugPrint("--- ALARME DISPARADO! --- Hora: $agora ---");

  flutterLocalNotificationsPlugin.show(
    agora.millisecond,
    'Hora do Medicamento',
    'Disparado às ${DateFormat('HH:mm:ss').format(agora)}',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelMedicamentos.id,
        channelMedicamentos.name,
        channelDescription: channelMedicamentos.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}
