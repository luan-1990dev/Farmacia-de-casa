import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

// 3. Função de Callback para o AlarmManager
@pragma('vm:entry-point')
void dispararAlarme() {
  // A lógica para mostrar a notificação vai aqui.
  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond,
    'Hora do Medicamento',
    'Está na hora de tomar seu remédio!',
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
