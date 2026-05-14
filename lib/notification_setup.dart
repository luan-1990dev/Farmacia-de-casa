import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'database_helper.dart';

// Instância única do plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // 1. Inicializar as amarrações do Flutter dentro deste Isolate separado
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // 2. O Isolate precisa ler o fuso horário nativo do dispositivo novamente aqui dentro
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

  debugPrint("🔔 EVENTO EM BACKGROUND: ${response.actionId}");

  // --- VERIFICAÇÃO DE TIPO: VALIDADE ---
  if (tipo == 'validade') {
    debugPrint("👀 Usuário visualizou alerta de validade de: $titulo");
    // Alertas de validade são informativos, não precisam de reagendamento ou marcação no banco
    return;
  }

  // --- AÇÃO: TOMEI ---
  if (response.actionId == 'TOME_I_ACTION') {
    debugPrint("✅ Ação 'Tomei' disparada em background para: $titulo");
    await DatabaseHelper().marcarDoseTomada(docId);
  }

  // --- AÇÃO: ADIAR 5 MINUTOS ---
  else if (response.actionId == 'ADIAR_5_MIN_ACTION') {
    debugPrint("⏰ Calculando adiamento de $titulo para mais 5 minutos");

    final agora = tz.TZDateTime.now(tz.local);
    final novoHorario = agora.add(const Duration(minutes: 5));

    await agendarNotificacaoGeral(
      id: "${docId}_adiado",
      titulo: "REPETIÇÃO: $titulo",
      corpo: "Lembrete adiado em 5 minutos.",
      dataHora: novoHorario,
      tipo: tipo,
    );

    debugPrint("🚀 Novo alarme adiado agendado com sucesso para $novoHorario");
  }
}

// --- INICIALIZAÇÃO DO SERVIÇO ---
Future<void> initNotificationService() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('icone_notificacao');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        final String titulo = data['titulo'] ?? "Medicamento";

        if (data['type'] == 'validade') {
          debugPrint("👀 Alerta de validade clicado: $titulo");
          return;
        }

        if (response.actionId == 'TOME_I_ACTION') {
          await DatabaseHelper().marcarDoseTomada(data['docId']);
          debugPrint("✅ Dose confirmada com app aberto");
        }
        else if (response.actionId == 'ADIAR_5_MIN_ACTION') {
          final novoHorario = DateTime.now().add(const Duration(minutes: 5));
          await agendarNotificacaoGeral(
            id: "${data['docId']}_adiado",
            titulo: "REPETIÇÃO: $titulo",
            corpo: "Lembrete adiado em 5 minutos.",
            dataHora: novoHorario,
            tipo: data['type'],
          );
          debugPrint("⏰ Alarme adiado com app aberto");
        }
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'saude_channel',
    'Lembretes de Saúde',
    description: 'Canal para alertas de medicamentos e exames',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
    await androidPlugin.requestExactAlarmsPermission();
  }
}

// --- FUNÇÃO DE AGENDAMENTO GERAL ---
Future<void> agendarNotificacaoGeral({
  required String id,
  required String titulo,
  required String corpo,
  required DateTime dataHora,
  required String tipo,
}) async {
  try {
    final scheduleDateTime = tz.TZDateTime.from(dataHora, tz.local);

    if (scheduleDateTime.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint("⚠️ Erro: Data $scheduleDateTime já passou.");
      return;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id.hashCode.abs(),
      titulo,
      corpo,
      scheduleDateTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'saude_channel',
          'Lembretes de Saúde',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          actions: tipo == 'medicamento'
              ? <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'TOME_I_ACTION',
              'OK, TOMEI',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'ADIAR_5_MIN_ACTION',
              'ADIAR 5 MIN',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ]
              : null,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock, // Alterado para alarmClock para maior precisão
      payload: jsonEncode({'type': tipo, 'docId': id, 'titulo': titulo}),
    );

    debugPrint("✅ Agendado com sucesso para: $scheduleDateTime");
  } catch (e) {
    debugPrint("❌ Erro no agendamento: $e");
  }
}

// --- FUNÇÃO: AGENDAR ALERTAS DE VALIDADE ---
Future<void> agendarAlertaValidade({
  required String id,
  required String nome,
  required DateTime dataValidade,
}) async {
  try {
    final localTimezone = tz.local;
    final dataVencimento = tz.TZDateTime.from(dataValidade, localTimezone);
    final agora = tz.TZDateTime.now(localTimezone);

    // 1. ALERTA: VENCIDO HOJE (Agendado para as 08:00 da manhã do dia)
    final tempoVencido = tz.TZDateTime(localTimezone, dataVencimento.year, dataVencimento.month, dataVencimento.day, 8, 0);

    if (tempoVencido.isAfter(agora)) {
      await _programarNotificacaoValidade(
        id: id.hashCode.abs() + 1000,
        titulo: "🚨 MEDICAMENTO VENCIDO!",
        corpo: "O prazo de validade de $nome expirou hoje.",
        data: tempoVencido,
        docId: id,
      );
    }

    // 2. ALERTA: VENCE EM 30 DIAS
    final tempoAvisoPrevio = tempoVencido.subtract(const Duration(days: 30));
    if (tempoAvisoPrevio.isAfter(agora)) {
      await _programarNotificacaoValidade(
        id: id.hashCode.abs() + 2000,
        titulo: "⚠️ Vencimento Próximo",
        corpo: "$nome vencerá em 30 dias. Verifique seu estoque.",
        data: tempoAvisoPrevio,
        docId: id,
      );
    }
  } catch (e) {
    debugPrint("❌ Erro ao agendar validade: $e");
  }
}

// Função privada auxiliar para agendar validade
Future<void> _programarNotificacaoValidade({
  required int id,
  required String titulo,
  required String corpo,
  required tz.TZDateTime data,
  required String docId,
}) async {
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    titulo,
    corpo,
    data,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'saude_channel',
        'Lembretes de Saúde',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.alarmClock,
    payload: jsonEncode({'type': 'validade', 'docId': docId, 'titulo': titulo}),
  );
  debugPrint("📅 Alerta de validade agendado: $titulo para $data");
}

// --- FUNÇÕES DE LIMPEZA E DEBUG ---
Future<void> limparTudo() async {
  await flutterLocalNotificationsPlugin.cancelAll();
  debugPrint("🚨 SISTEMA LIMPO: Todos os alarmes removidos.");
}

Future<void> listarNotificacoesPendentes() async {
  final List<PendingNotificationRequest> pendingRequests =
  await flutterLocalNotificationsPlugin.pendingNotificationRequests();

  debugPrint("--- [DEBUG FILA] Total: ${pendingRequests.length} ---");
  for (var req in pendingRequests) {
    debugPrint("ID: ${req.id} | Titulo: ${req.title} | Payload: ${req.payload}");
  }
}

Future<void> dispararDoseTeste() async {
  final DateTime horarioTeste = DateTime.now().add(const Duration(seconds: 10));
  await agendarNotificacaoGeral(
    id: "teste_id_999",
    titulo: "Dose de Teste 💊",
    corpo: "Se você viu isso, a automação está funcionando!",
    dataHora: horarioTeste,
    tipo: "medicamento",
  );
}
