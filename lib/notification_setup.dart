import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  try {
    final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  }

  if (response.payload == null) return;
  final Map<String, dynamic> data = jsonDecode(response.payload!);

  final String docId = data['docId'] ?? "";
  final String titulo = data['titulo'] ?? "Medicamento";
  final String tipo = data['type'] ?? "medicamento";
  final int intervalo = data['intervalo'] ?? 8;

  if (response.id != null) {
    await flutterLocalNotificationsPlugin.cancel(response.id!);
  }

  else if (response.actionId == 'TOME_I_ACTION') {
    await DatabaseHelper().marcarDoseTomada(docId);
    final agora = tz.TZDateTime.now(tz.local);
    final proximaDose = agora.add(Duration(hours: intervalo));

    await agendarNotificacaoGeral(
      id: docId,
      titulo: titulo,
      corpo: "Hora da sua próxima dose.",
      dataHora: proximaDose,
      tipo: tipo,
      intervalo: intervalo,
    );
    debugPrint("♻️ [TOMEI] Próxima dose automática agendada para daqui a $intervalo horas.");
  }

  else if (response.actionId == 'CANCELAR_ALARMES_ACTION') {
    await cancelarLembrete(docId);
    debugPrint("🛑 Ciclo de alarmes encerrado para $titulo.");
  }

  // --- AÇÃO: CIENTE ---
  else if (response.actionId == 'CIENTE_ACTION') {
    await DatabaseHelper().marcarCompromissoComoConcluido(docId);
  }
}

Future<void> initNotificationService() async {
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('icone_notificacao');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);

        if (data['type'] == 'validade') {
          navigatorKey.currentState?.pushNamed('/estoque', arguments: {'aba': 1});
          return;
        }
        final String docId = data['docId'] ?? "";
        final String titulo = data['titulo'] ?? "Medicamento";
        final String tipo = data['type'] ?? "medicamento";
        final int intervalo = data['intervalo'] ?? 8;

        if (response.id != null) await flutterLocalNotificationsPlugin.cancel(response.id!);

        if (response.actionId == 'ADIAR_5_MIN_ACTION') {
          final novoHorario = DateTime.now().add(const Duration(minutes: 5));
          await agendarNotificacaoGeral(
            id: docId,
            titulo: titulo,
            corpo: "Lembrete adiado (Soneca de 5 min)",
            dataHora: novoHorario,
            tipo: data['type'],
            intervalo: data['intervalo'] ?? 8,
          );
        }
        else if (response.actionId == 'TOME_I_ACTION') {
          await DatabaseHelper().marcarDoseTomada(docId);
        }
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
      'saude_channel', 'Lembretes de Saúde', importance: Importance.max, playSound: true, enableVibration: true,
    ));
    final bool? concedida = await androidPlugin.requestNotificationsPermission();

    if (concedida == false) {
      _mostrarDialogoPermissaoNecessaria();
    }
    await androidPlugin.requestExactAlarmsPermission();
  }
}

void _mostrarDialogoPermissaoNecessaria() {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Notificações Desativadas"),
      content: const Text(
          "Sem as notificações, você não será avisado sobre seus medicamentos. "
              "Deseja ativar agora nas configurações?"
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("AGORA NÃO"),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await openAppSettings();
          },
          child: const Text("ABRIR CONFIGURAÇÕES"),
        ),
      ],
    ),
  );
}

Future<void> agendarNotificacaoGeral({
  required String id,
  required String titulo,
  required String corpo,
  required DateTime dataHora,
  required String tipo,
  int intervalo = 8,
}) async {
  try {
    final scheduleDateTime = tz.TZDateTime.from(dataHora, tz.local);
    if (scheduleDateTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    String h = DateFormat("HH:mm").format(dataHora);
    String d = DateFormat("dd/MM/yy").format(dataHora);
    String corpoFinal = tipo == 'exame' ? "Compromisso: $titulo" : "Dose das $h do dia $d. $corpo";

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id.hashCode.abs(),
      tipo == 'exame' ? 'Lembrete de Compromisso' : titulo,
      corpoFinal,
      scheduleDateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
            'saude_channel', 'Lembretes de Saúde',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ongoing: false,
            autoCancel: true,
            actions: tipo == 'medicamento'
                ? [
              const AndroidNotificationAction('TOME_I_ACTION', 'OK, TOMEI', showsUserInterface: true, cancelNotification: true),
              const AndroidNotificationAction('ADIAR_5_MIN_ACTION', 'ADIAR 5 MIN', showsUserInterface: true, cancelNotification: true),
              const AndroidNotificationAction('CANCELAR_ALARMES_ACTION', 'PARAR ALARMES', showsUserInterface: true, cancelNotification: true),
            ]
                : [
              const AndroidNotificationAction('CIENTE_ACTION', 'CIENTE', showsUserInterface: true, cancelNotification: true),
            ]
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        'type': tipo, 'docId': id, 'titulo': titulo, 'intervalo': intervalo, 'dataHora': dataHora.toIso8601String()
      }),
    );
  } catch (e) { debugPrint("❌ Erro agendamento: $e"); }
}

Future<void> cancelarLembrete(String docId) async {
  final int idPrincipal = docId.hashCode.abs();
  final int idAdiado = "${docId}_adiado".hashCode.abs();

  await flutterLocalNotificationsPlugin.cancel(idPrincipal);
  await flutterLocalNotificationsPlugin.cancel(idAdiado);

  debugPrint("🚫 Lembrete $docId e derivados removidos do sistema.");
}

Future<void> agendarAlertaValidade({required String id, required String nome, required DateTime dataValidade}) async {
  final tempoVencido = tz.TZDateTime(tz.local, dataValidade.year, dataValidade.month, dataValidade.day, 8, 0);
  if (tempoVencido.isAfter(tz.TZDateTime.now(tz.local))) {
    await agendarNotificacaoGeral(
        id: "${id}_val",
        titulo: "🚨 VENCIDO: $nome",
        corpo: "A validade expirou hoje.",
        dataHora: tempoVencido,
        tipo: 'validade'
    );
  }
}