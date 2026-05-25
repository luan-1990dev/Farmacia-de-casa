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
  String? usageType;
  bool usoContinuo = false;
  String? frequencia;
  int? intervaloCustomizado;
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
          AndroidNotificationAction('TOME_I_ACTION', 'OK, Tomei', showsUserInterface: true),
        ],
      ),
    );
  }

  // --- DIÁLOGO PARA EDITAR PERÍODO (HORAS) ---
  Future<int?> _showDialogIntervalo() async {
    int tempHoras = 4;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Definir Intervalo"),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Tomar o medicamento a cada quantas horas?"),
                const SizedBox(height: 20),
                DropdownButton<int>(
                  isExpanded: true,
                  value: tempHoras,
                  items: List.generate(24, (i) => i + 1)
                      .map((h) => DropdownMenuItem(value: h, child: Text("$h horas")))
                      .toList(),
                  onChanged: (v) => setDialogState(() => tempHoras = v!),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(onPressed: () => Navigator.pop(context, tempHoras), child: const Text("SALVAR")),
        ],
      ),
    );
  }

  String? _obterCampoFaltante() {
    if (nomeController.text.trim().isEmpty) return "Nome do medicamento";
    if (usageType == null) return "Uso";
    if (frequencia == null) return "Frequência";
    if (modoUso == null) return "Modo de uso";
    if (horarios.isEmpty) return "Horários";
    if (dataInicial == null) return "Data inicial";
    if (!usoContinuo && dataFinal == null) return "Data final";
    return null;
  }

  Future<void> _agendarNotificacao(String localId, String nomeMedicamento, DateTime dataHoraDose) async {
    try {
      final scheduledDate = tz.TZDateTime.from(dataHoraDose, tz.local);
      final int safeId = (localId.hashCode + dataHoraDose.millisecondsSinceEpoch) & 0x7FFFFFFF;

      String horaFormatada = DateFormat("HH:mm").format(dataHoraDose);
      String dataFormatada = DateFormat("dd/MM/yy").format(dataHoraDose);

      final payload = jsonEncode({
        'type': 'medicamento',
        'docId': localId,
        'titulo': nomeMedicamento,
        'intervalo': intervaloCustomizado ?? 8,
        'dataHora': dataHoraDose.toIso8601String(),
      });

      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        'Lembrete de medicamento',
        'Dose das $horaFormatada do dia $dataFormatada. Está na hora de tomar $nomeMedicamento.',
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exact, // Alterado para maior confiabilidade
        payload: jsonEncode({
          'type': 'medicamento',
          'docId': localId,
          'titulo': nomeMedicamento,
          'intervalo': 24,
          // CORREÇÃO: Utilizando 'scheduledDate' convertida para string ISO 8601
          'dataHora': scheduledDate.toIso8601String(),
        }),
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint("✅ Agendado: $nomeMedicamento para $horaFormatada de $dataFormatada");
    } catch (e) {
      debugPrint("ERRO DIÁRIO: $e");
    }
  }

  Future<void> _agendarNotificacaoDiaria(String localId, String nomeMedicamento, TimeOfDay horario) async {
    try {
      final agora = DateTime.now();
      DateTime dataAgendada = DateTime(agora.year, agora.month, agora.day, horario.hour, horario.minute);
      if (dataAgendada.isBefore(agora)) dataAgendada = dataAgendada.add(const Duration(days: 1));

      final scheduledDate = tz.TZDateTime.from(dataAgendada, tz.local);
      final int safeId = (localId.hashCode + horario.hour + horario.minute) & 0x7FFFFFFF;

      String horaFormatada = DateFormat("HH:mm").format(dataAgendada);
      String dataFormatada = DateFormat("dd/MM/yy").format(dataAgendada);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        'Lembrete de medicamento',
        'Dose das $horaFormatada do dia $dataFormatada. Está na hora de tomar seu $nomeMedicamento.',
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({
          'type': 'medicamento',
          'docId': localId,
          'titulo': nomeMedicamento,
          'intervalo': 24,
          'dataHora': dataAgendada.toIso8601String(),
        }),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint("ERRO DIÁRIO: $e");
    }
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

      await _dbHelper.inserirTratamento({
        'id': localId, 'nome': nomeController.text, 'isAntibiotico': isAntibiotico ? 1 : 0,
        'isFormulado': isFormulado ? 1 : 0, 'uso': usageType, 'usoContinuo': usoContinuo ? 1 : 0,
        'frequencia': frequencia, 'modoUso': modoUso, 'dataInicial': dataInicial!.toIso8601String(),
        'dataFinal': dataFinal!.toIso8601String(), 'infoAdicional': infoController.text,
        'userId': _currentUser?.uid, 'sincronizado': 0,
      });

      if (frequencia == "Diário") {
        for (TimeOfDay horario in horarios) {
          await _agendarNotificacaoDiaria(localId, nomeController.text, horario);
        }
      } else {
        for (int i = 0; i <= 3; i++) {
          for (TimeOfDay horario in horarios) {
            DateTime dataHoraDose = DateTime(dataInicial!.year, dataInicial!.month, dataInicial!.day, horario.hour, horario.minute).add(Duration(days: i));
            if (dataHoraDose.isAfter(DateTime.now())) {
              await _agendarNotificacao(localId, nomeController.text, dataHoraDose);
            }
          }
        }
      }

      if (_currentUser != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('tratamentos').doc(localId).set({
          'nome': nomeController.text, 'isAntibiotico': isAntibiotico, 'isFormulado': isFormulado,
          'uso': usageType, 'usoContinuo': usoContinuo, 'frequencia': frequencia, 'modoUso': modoUso,
          'horarios': horarios.map((h) => "${h.hour}:${h.minute}").toList(),
          'dataInicial': dataInicial, 'dataFinal': dataFinal,
          'infoAdicional': infoController.text, 'criadoEm': FieldValue.serverTimestamp(),
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
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
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
            child: Center(
                child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaAlarmesPage(tipo: 'medicamento'))),
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.7), blurRadius: 12, spreadRadius: 2)]
                        ),
                        child: const Icon(Icons.alarm, color: Colors.deepOrange, size: 28)
                    )
                )
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
                _buildSectionCard(title: "Informações do Medicamento", icon: Icons.medication, children: [
                  TextFormField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: "Nome do medicamento*", prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Antibiótico?"), value: isAntibiotico, onChanged: (v) => setState(() => isAntibiotico = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Este medicamento é formulado?"), value: isFormulado, onChanged: (v) => setState(() => isFormulado = v)),
                ]),
                const SizedBox(height: 16),
                _buildSectionCard(title: "Programação", icon: Icons.schedule, children: [
                  DropdownButtonFormField<String>(value: usageType, items: ["Adulto", "Infantil"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => usageType = v), decoration: const InputDecoration(labelText: "Uso*", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      value: frequencia,
                      items: ["Diário", "08 em 08 horas", "12 em 12 horas", "Editar período"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) async {
                        if (v == "Editar período") {
                          final int? horas = await _showDialogIntervalo();
                          if (horas != null) {
                            setState(() {
                              frequencia = v;
                              intervaloCustomizado = horas;
                              periodoCustomizado = "A cada $horas horas";
                            });
                          }
                        } else {
                          setState(() {
                            frequencia = v;
                            if (v == "08 em 08 horas") intervaloCustomizado = 8;
                            else if (v == "12 em 12 horas") intervaloCustomizado = 12;
                            else if (v == "Diário") intervaloCustomizado = 24;
                            periodoCustomizado = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                          labelText: "Frequência*",
                          helperText: periodoCustomizado,
                          prefixIcon: const Icon(Icons.repeat),
                          border: const OutlineInputBorder()
                      )
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(value: modoUso, items: ["Comprimidos", "Cápsulas", "ml", "Gotas", "Doses"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => modoUso = v), decoration: const InputDecoration(labelText: "Modo de uso*", prefixIcon: Icon(Icons.layers_outlined), border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () async { final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now()); if (picked != null) setState(() => horarios.add(picked)); }, icon: const Icon(Icons.add_alarm), label: const Text("Adicionar Horário*")),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: horarios.map((h) => Chip(label: Text("${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}"), onDeleted: () => setState(() => horarios.remove(h)))).toList()),
                ]),
                const SizedBox(height: 16),
                _buildSectionCard(title: "Duração", icon: Icons.calendar_today, children: [
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Uso contínuo"), value: usoContinuo, onChanged: (v) => setState(() => usoContinuo = v)),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _selecionarData(context, (d) => setState(() => dataInicial = d)), child: Text(dataInicial == null ? "Data de Início*" : "Início: ${DateFormat('dd/MM/yy').format(dataInicial!)}"))),
                    if (!usoContinuo) ...[const SizedBox(width: 12), Expanded(child: OutlinedButton(onPressed: () => _selecionarData(context, (d) => setState(() => dataFinal = d)), child: Text(dataFinal == null ? "Data de Fim*" : "Fim: ${DateFormat('dd/MM/yy').format(dataFinal!)}")))],
                  ]),
                ]),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: _isLoading ? null : finalizar, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 18)), child: const Text("FINALIZAR")),
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