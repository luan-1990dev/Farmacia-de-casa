import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// 1. Instância única e centralizada
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 2. Definição dos Canais
const AndroidNotificationChannel channelMedicamentos = AndroidNotificationChannel(
  'lembrete_medicamento_channel',
  'Lembretes Críticos de Medicamentos',
  description: 'Canal para alertas urgentes sobre medicamentos.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

const AndroidNotificationChannel channelCompromissos = AndroidNotificationChannel(
  'lembrete_compromisso_channel',
  'Lembretes de Compromissos',
  description: 'Canal para lembretes de exames e consultas.',
  importance: Importance.high,
  playSound: true,
);

// 3. Função de Inicialização Mestra
Future<void> initNotificationService() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // Inicializa o plugin com tratamento de resposta (Essencial para o Android não bloquear)
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("Notificação clicada! Payload: ${response.payload}");
      // Aqui podemos adicionar a lógica para o botão "Tomei" no futuro
    },
  );

  // Registra os canais no sistema operacional
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channelMedicamentos);
    await androidPlugin.createNotificationChannel(channelCompromissos);
    // Solicita permissão para alarmes exatos (Android 13+)
    await androidPlugin.requestExactAlarmsPermission();
  }
}
