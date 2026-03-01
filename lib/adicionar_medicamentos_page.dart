import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmacia_de_casa/lista_alarmes_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'notification_setup.dart';
import 'database_helper.dart';

class AdicionarMedicamentosPage extends StatefulWidget {
  const AdicionarMedicamentosPage({super.key});

  @override
  State<AdicionarMedicamentosPage> createState() => _AdicionarMedicamentosPageState();
}

class _AdicionarMedicamentosPageState extends State<AdicionarMedicamentosPage> {
  bool _isLoading = false;
  final _dbHelper = DatabaseHelper();

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
        'lembrete_medicamento_channel', 
        'Lembretes Críticos de Medicamentos',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('TOME_I_ACTION', 'Tomei o remédio', showsUserInterface: true),
          AndroidNotificationAction('ADIAR_15_MIN_ACTION', 'Adiar 15 min'),
        ],
      ),
    );
  }

  String? _obterCampoFaltante() {
    if (nomeController.text.trim().isEmpty) return "Nome do medicamento";
    if (uso == null) return "Uso";
    if (frequencia == null) return "Frequência";
    if (modoUso == null) return "Modo de uso";
    if (horarios.isEmpty) return "Horários";
    if (dataInicial == null) return "Data inicial";
    if (!usoContinuo && dataFinal == null) return "Data final";
    return null;
  }

  Future<void> _agendarNotificacao(String localId, String nomeMedicamento, DateTime dataHoraDose) async {
    try {
      // CONSTRUÇÃO MANUAL DO TZDATETIME (Resolve o erro de 3 horas)
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dataHoraDose.year,
        dataHoraDose.month,
        dataHoraDose.day,
        dataHoraDose.hour,
        dataHoraDose.minute,
      );

      final int safeId = (localId.hashCode + dataHoraDose.millisecondsSinceEpoch) & 0x7FFFFFFF;
      
      final payload = jsonEncode({
        'type': 'medicamento',
        'localId': localId,
        'dataHora': dataHoraDose.toIso8601String(), // Salva string local limpa
      });

      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        'Hora do Medicamento',
        'Está na hora de tomar seu $nomeMedicamento',
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint("ERRO AO AGENDAR: $e");
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final DateTime now = DateTime.now(); 
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduledDate, tz.local);
  }

  Future<void> finalizar() async {
    if (_isLoading) return;
    final String? campoFaltante = _obterCampoFaltante();
    if (campoFaltante != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Campo obrigatório: $campoFaltante"), backgroundColor: Colors.orangeAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String localId = const Uuid().v4();
      if (usoContinuo && dataFinal == null) dataFinal = dataInicial!.add(const Duration(days: 365 * 2));

      // 1. SALVAR LOCAL
      await _dbHelper.inserirTratamento({
        'id': localId, 'nome': nomeController.text, 'isAntibiotico': isAntibiotico ? 1 : 0,
        'isFormulado': isFormulado ? 1 : 0, 'uso': uso, 'usoContinuo': usoContinuo ? 1 : 0,
        'frequencia': frequencia, 'modoUso': modoUso, 'dataInicial': dataInicial!.toIso8601String(),
        'dataFinal': dataFinal!.toIso8601String(), 'infoAdicional': infoController.text,
        'userId': _currentUser?.uid, 'sincronizado': 0,
      });

      // 2. AGENDAR APENAS OS PRÓXIMOS 3 DIAS (Evita poluição e erro de limite do Android)
      for (int i = 0; i <= 3; i++) {
        for (TimeOfDay horario in horarios) {
          DateTime dataHoraDose = DateTime(dataInicial!.year, dataInicial!.month, dataInicial!.day, horario.hour, horario.minute).add(Duration(days: i));

          if (dataHoraDose.isAfter(DateTime.now())) {
            await _agendarNotificacao(localId, nomeController.text, dataHoraDose);
            await _dbHelper.inserirDose({
              'tratamentoId': localId, 'medicamentoNome': nomeController.text,
              'dataHora': dataHoraDose.toIso8601String(), 'tomado': 0, 'sincronizado': 0,
            });
          }
        }
      }

      // 3. FIRESTORE
      if (_currentUser != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('tratamentos').doc(localId).set({
          'nome': nomeController.text, 'isAntibiotico': isAntibiotico, 'isFormulado': isFormulado,
          'uso': uso, 'usoContinuo': usoContinuo, 'frequencia': frequencia, 'modoUso': modoUso,
          'horarios': horarios.map((h) => "${h.hour}:${h.minute}").toList(),
          'dataInicial': dataInicial, 'dataFinal': dataFinal, 'infoAdicional': infoController.text,
          'criadoEm': FieldValue.serverTimestamp(),
        });
        await _dbHelper.marcarComoSincronizado('tratamentos', localId);
      }

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tratamento agendado com sucesso!"), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (e.toString().contains("exact_alarms_not_permitted")) {
        _showPermissaoDialog();
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _showPermissaoDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Permissão Necessária"), content: const Text("Ative a permissão de 'Alarmes e lembretes' para horários exatos."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLTAR")), ElevatedButton(onPressed: () async { Navigator.pop(context); await openAppSettings(); }, child: const Text("ATIVAR"))]));
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
            child: Center(child: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaAlarmesPage(tipo: 'medicamento'))), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.7), blurRadius: 12, spreadRadius: 2)]), child: const Icon(Icons.alarm, color: Colors.deepOrange, size: 28)))),
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
                _buildSectionCard(title: "Informações do Medicamento", icon: Icons.medication, children: [
                    TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: "Nome do medicamento*", prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Antibiótico?"), value: isAntibiotico, onChanged: (v) => setState(() => isAntibiotico = v)),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Formulado?"), value: isFormulado, onChanged: (v) => setState(() => isFormulado = v)),
                ]),
                const SizedBox(height: 16),
                _buildSectionCard(title: "Programação", icon: Icons.schedule, children: [
                    DropdownButtonFormField<String>(value: uso, items: ["Adulto", "Infantil"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => uso = v), decoration: const InputDecoration(labelText: "Uso*", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(value: frequencia, items: ["Diário", "08 em 08 horas", "12 em 12 horas", "Dias alternados", "Editar período"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => frequencia = v), decoration: const InputDecoration(labelText: "Frequência*", prefixIcon: Icon(Icons.repeat), border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(value: modoUso, items: ["Comprimidos", "Cápsulas", "ml", "Gotas", "Doses", "Aplicações", "Unidades"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => modoUso = v), decoration: const InputDecoration(labelText: "Modo de uso*", prefixIcon: Icon(Icons.layers_outlined), border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: () async { final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (picked != null) setState(() => horarios.add(picked)); }, icon: const Icon(Icons.add_alarm), label: const Text("Adicionar Horário*"), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: horarios.map((h) => Chip(label: Text("${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}"), onDeleted: () => setState(() => horarios.remove(h)), backgroundColor: Colors.blue.shade50, deleteIconColor: Colors.red)).toList()),
                ]),
                const SizedBox(height: 16),
                _buildSectionCard(title: "Duração", icon: Icons.calendar_today, children: [
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Uso contínuo"), value: usoContinuo, onChanged: (v) => setState(() => usoContinuo = v)),
                    const SizedBox(height: 8),
                    Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => _selecionarData(context, (d) => setState(() => dataInicial = d)), child: Text(dataInicial == null ? "Início*" : DateFormat('dd/MM/yy').format(dataInicial!)))),
                        if (!usoContinuo) ...[const SizedBox(width: 12), Expanded(child: OutlinedButton(onPressed: () => _selecionarData(context, (d) => setState(() => dataFinal = d)), child: Text(dataFinal == null ? "Fim*" : DateFormat('dd/MM/yy').format(dataFinal!))))],
                    ]),
                ]),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: _isLoading ? null : finalizar, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("FINALIZAR")),
              ],
            ),
          ),
          if (_isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon, color: Colors.blue.shade800, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]), const Divider(height: 24), ...children])));
  }

  Future<void> _selecionarData(BuildContext context, Function(DateTime) onSelected) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) onSelected(picked);
  }
}
