import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmacia_de_casa/lista_alarmes_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_setup.dart'; // Importa o novo arquivo centralizado

class AdicionarMedicamentosPage extends StatefulWidget {
  const AdicionarMedicamentosPage({super.key});

  @override
  State<AdicionarMedicamentosPage> createState() => _AdicionarMedicamentosPageState();
}

class _AdicionarMedicamentosPageState extends State<AdicionarMedicamentosPage> {
  bool _isLoading = false;

  final TextEditingController nomeController = TextEditingController();
  bool isAntibiotico = false;
  bool isFormulado = false;
  String? uso;
  bool usoContinuo = false;
  String? frequencia;
  String? periodoCustomizado;
  String? modoUso;
  DateTime? dataInicial;
  DateTime? dataFinal;
  List<TimeOfDay> horarios = [];
  final TextEditingController infoController = TextEditingController();
  final TextEditingController periodoController = TextEditingController();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'lembrete_medicamento_channel', // ID do canal
        'Lembretes Críticos de Medicamentos',
        channelDescription: 'Canal para alertas urgentes sobre medicamentos.',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'TOME_I_ACTION',
            'Tomei o remédio',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'ADIAR_15_MIN_ACTION',
            'Adiar 15 min',
          ),
        ],
      ),
    );
  }

  bool _validarCampos() {
    bool datasValidas = dataInicial != null && (usoContinuo || dataFinal != null);
    return nomeController.text.isNotEmpty &&
        frequencia != null &&
        frequencia!.isNotEmpty &&
        modoUso != null &&
        modoUso!.isNotEmpty &&
        horarios.isNotEmpty &&
        datasValidas;
  }

  Future<void> _agendarNotificacao(String docId, String nomeMedicamento, DateTime dataHoraDose) async {
    try {
      // CORREÇÃO: Construção manual do TZDateTime para evitar conversão dupla
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dataHoraDose.year,
        dataHoraDose.month,
        dataHoraDose.day,
        dataHoraDose.hour,
        dataHoraDose.minute,
      );

      final int safeId = (docId.hashCode + dataHoraDose.millisecondsSinceEpoch) & 0x7FFFFFFF;
      final String body = 'Está na hora de tomar seu $nomeMedicamento';

      final payload = jsonEncode({
        'type': 'medicamento',
        'docId': docId,
        'dataHora': dataHoraDose.toIso8601String(),
      });

      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        'Hora do Medicamento',
        body,
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint("ERRO AO AGENDAR NOTIFICAÇÃO: $e");
    }
  }

  Future<void> _agendarNotificacaoDiaria(String docId, String nomeMedicamento, TimeOfDay horario) async {
    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(horario);
    final int safeId = (docId.hashCode + horario.hour + horario.minute) & 0x7FFFFFFF;
    final String body = 'Está na hora de tomar seu $nomeMedicamento';

    final payload = jsonEncode({
      'type': 'medicamento',
      'docId': docId,
      'dataHora': scheduledDate.toIso8601String(),
    });

    await flutterLocalNotificationsPlugin.zonedSchedule(
      safeId,
      'Hora do Medicamento',
      body,
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }


  Future<void> finalizar() async {
    if (_isLoading) return;

    if (!_validarCampos()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos obrigatórios antes de finalizar")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (usoContinuo && dataFinal == null) {
        dataFinal = dataInicial!.add(const Duration(days: 365 * 2));
      }

      if (_currentUser != null) {
        final docRef = await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('tratamentos').add({
          'nome': nomeController.text,
          'isAntibiotico': isAntibiotico,
          'isFormulado': isFormulado,
          'uso': uso,
          'usoContinuo': usoContinuo,
          'frequencia': frequencia == "Editar período" ? periodoCustomizado ?? frequencia : frequencia,
          'modoUso': modoUso,
          'horarios': horarios.map((h) => "${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}").toList(),
          'dataInicial': dataInicial,
          'dataFinal': dataFinal,
          'infoAdicional': infoController.text,
          'criadoEm': FieldValue.serverTimestamp(),
        });

        if (frequencia == "Diário") {
          for (var horario in horarios) {
            await _agendarNotificacaoDiaria(docRef.id, nomeController.text, horario);
          }
        } else {
          int diasTotais = dataFinal!.difference(dataInicial!).inDays;
          if (diasTotais > 90) diasTotais = 90; 

          for (int i = 0; i <= diasTotais; i++) {
            for (TimeOfDay horario in horarios) {
              DateTime dataHoraDose = dataInicial!.add(Duration(days: i, hours: horario.hour, minutes: horario.minute));
              if (dataHoraDose.isAfter(tz.TZDateTime.now(tz.local))) {
                await _agendarNotificacao(docRef.id, nomeController.text, dataHoraDose);
              }
            }
          }
        }
      }

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tratamento salvo e lembretes agendados!"), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Adicionar Tratamento"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaAlarmesPage(tipo: 'medicamento'))), 
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.deepOrange.withAlpha(179), blurRadius: 12, spreadRadius: 2)]),
                  child: const Icon(Icons.alarm, color: Colors.deepOrange, size: 28),
                ),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: "Nome do medicamento*")),
                  const SizedBox(height: 16),
                  SwitchListTile(title: const Text("É antibiótico?"), value: isAntibiotico, onChanged: (val) => setState(() => isAntibiotico = val)),
                  SwitchListTile(title: const Text("É medicamento formulado?"), value: isFormulado, onChanged: (val) => setState(() => isFormulado = val)),
                  DropdownButtonFormField<String>(initialValue: uso, items: ["Adulto", "Infantil"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => uso = val), decoration: const InputDecoration(labelText: "Uso*")),
                  SwitchListTile(title: const Text("Uso contínuo"), value: usoContinuo, onChanged: (val) => setState(() => usoContinuo = val)),
                  DropdownButtonFormField<String>(initialValue: frequencia, items: ["Diário", "08 em 08 horas", "12 em 12 horas", "Dias alternados", "Editar período"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => frequencia = val), decoration: const InputDecoration(labelText: "Frequência*")),
                  if (frequencia == "Editar período") TextFormField(controller: periodoController, decoration: const InputDecoration(labelText: "Informe o período manualmente"), onChanged: (val) => setState(() => periodoCustomizado = val)),
                  DropdownButtonFormField<String>(initialValue: modoUso, items: ["Comprimidos", "Cápsulas", "ml", "Gotas", "Doses", "Aplicações", "Unidades"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => modoUso = val), decoration: const InputDecoration(labelText: "Modo de uso*")),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (picked != null) setState(() => horarios.add(picked));
                    }, child: const Text("Adicionar horário*")),
                  Wrap(spacing: 8, children: horarios.map((h) => Chip(label: Text("${h.hour}:${h.minute.toString().padLeft(2, '0')}"), onDeleted: () => setState(() => horarios.remove(h)))).toList()),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => selecionarData(context, (d) => setState(() => dataInicial = d)), child: Text(dataInicial == null ? "Selecionar data inicial*" : "Data inicial: ${DateFormat('dd/MM/yyyy').format(dataInicial!)}")),
                  if (!usoContinuo) ElevatedButton(onPressed: () => selecionarData(context, (d) => setState(() => dataFinal = d)), child: Text(dataFinal == null ? "Selecionar data final*" : "Data final: ${DateFormat('dd/MM/yyyy').format(dataFinal!)}")),
                  if (usoContinuo) const Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("Para uso contínuo, os lembretes serão agendados por 2 anos.", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center)),
                  TextFormField(controller: infoController, decoration: const InputDecoration(labelText: "Informações adicionais")),
                  const SizedBox(height: 24),
                  SafeArea(top: false, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), onPressed: _isLoading ? null : finalizar, child: const Text("Finalizar"))))),
                ],
              ),
          ),
          if (_isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Future<void> selecionarData(BuildContext context, Function(DateTime) onSelected) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) onSelected(picked);
  }
}
