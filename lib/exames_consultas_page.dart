import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmacia_de_casa/lista_alarmes_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'notification_setup.dart'; // Importa o arquivo centralizado

class ExamesConsultasPage extends StatefulWidget {
  const ExamesConsultasPage({super.key});

  @override
  State<ExamesConsultasPage> createState() => _ExamesConsultasPageState();
}

class _ExamesConsultasPageState extends State<ExamesConsultasPage> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
  }

  NotificationDetails get _notificationDetails {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelCompromissos.id,
        channelCompromissos.name,
        channelDescription: channelCompromissos.description,
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,
      ),
    );
  }

  Future<void> _agendarNotificacao(String docId, String tipo, DateTime dataHora) async {
    final int safeId = docId.hashCode & 0x7FFFFFFF;
    final String body = 'Lembrete para $tipo em ${DateFormat('dd/MM/yyyy HH:mm').format(dataHora)}';

    try {
      final payload = jsonEncode({'type': 'compromisso', 'id': docId, 'dataHora': dataHora.toIso8601String()});

      // Agendamento principal com construção manual do TZDateTime
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dataHora.year,
        dataHora.month,
        dataHora.day,
        dataHora.hour,
        dataHora.minute,
      );
      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        'Lembrete de Compromisso',
        body,
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      // Agendamento de 1 dia antes
      if (dataHora.isAfter(DateTime.now().add(const Duration(days: 1)))) {
        final dataLembreteAntecipado = dataHora.subtract(const Duration(days: 1));
        final scheduledDateAntecipado = tz.TZDateTime(
            tz.local,
            dataLembreteAntecipado.year,
            dataLembreteAntecipado.month,
            dataLembreteAntecipado.day,
            dataLembreteAntecipado.hour,
            dataLembreteAntecipado.minute,        
        );

        await flutterLocalNotificationsPlugin.zonedSchedule(
          safeId - 1, // ID diferente
          'Lembrete: Amanhã!',
          body,
          scheduledDateAntecipado,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint("ERRO AO AGENDAR NOTIFICAÇÃO DE EXAME: $e");
    }
  }

  Future<void> _cancelarNotificacao(String docId) async {
    final int safeId = docId.hashCode & 0x7FFFFFFF;
    await flutterLocalNotificationsPlugin.cancel(safeId);
    await flutterLocalNotificationsPlugin.cancel(safeId - 1); 
  }

  Future<void> _finalizarCompromisso(DocumentReference docRef) async {
    await docRef.update({
      'status': 'Finalizado',
      'dataFinalizado': FieldValue.serverTimestamp(),
    });
    await _cancelarNotificacao(docRef.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Compromisso marcado como finalizado e lembretes removidos!"), backgroundColor: Colors.green),
      );
    }
  }

  void _adicionarEditarCompromisso([DocumentSnapshot? doc]) {
    final formKey = GlobalKey<FormState>();
    String? tipo = doc != null ? (doc.data() as Map<String, dynamic>)['tipo'] : null;
    final especialidadeController = TextEditingController(text: doc != null ? (doc.data() as Map<String, dynamic>)['especialidade'] : '');
    final localController = TextEditingController(text: doc != null ? (doc.data() as Map<String, dynamic>)['local'] : '');
    DateTime? dataHora = doc != null ? ((doc.data() as Map<String, dynamic>)['dataHora'] as Timestamp).toDate() : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(doc == null ? "Adicionar Compromisso" : "Editar Compromisso"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo de Compromisso'),
                        items: ['Exame', 'Consulta'].map((label) => DropdownMenuItem(child: Text(label), value: label)).toList(),
                        onChanged: (value) => setDialogState(() => tipo = value),
                        validator: (value) => value == null ? 'Campo obrigatório' : null,
                      ),
                      TextFormField(
                        controller: especialidadeController,
                        decoration: const InputDecoration(labelText: 'Especialidade'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      TextFormField(
                        controller: localController,
                        decoration: InputDecoration(
                          labelText: 'Local',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              final query = localController.text;
                              if (query.isNotEmpty) {
                                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
                                if (!await launchUrl(uri)) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Não foi possível abrir o mapa.")),
                                    );
                                  }
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Digite um local para pesquisar no mapa.")),
                                );
                              }
                            },
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        title: Text(dataHora == null ? 'Nenhuma data selecionada' : DateFormat('dd/MM/yyyy HH:mm').format(dataHora!)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final data = await showDatePicker(context: context, initialDate: dataHora ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                          if (data == null) return;
                          final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dataHora ?? DateTime.now()));
                          if (hora == null) return;
                          setDialogState(() {
                            dataHora = DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || dataHora == null) return;

                    final compromissoData = {
                      'tipo': tipo,
                      'especialidade': especialidadeController.text,
                      'local': localController.text,
                      'dataHora': Timestamp.fromDate(dataHora!),
                      'status': 'Pendente' // Adiciona status ao criar/editar
                    };

                    if (doc == null) {
                      final newDocRef = await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('exames').add(compromissoData);
                      await _agendarNotificacao(newDocRef.id, tipo!, dataHora!);
                    } else {
                      await doc.reference.update(compromissoData);
                      await _cancelarNotificacao(doc.id);
                      await _agendarNotificacao(doc.id, tipo!, dataHora!);
                    }
                    if(mounted) Navigator.of(context).pop();
                  },
                  child: const Text("Salvar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _excluirCompromisso(DocumentSnapshot doc) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Confirmar Exclusão"),
              content: const Text("Deseja realmente excluir este compromisso e seus lembretes?"),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                TextButton(
                  child: const Text("Excluir", style: TextStyle(color: Colors.red)),
                  onPressed: () async {
                    await _cancelarNotificacao(doc.id);
                    await doc.reference.delete();
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exames e Consultas"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaAlarmesPage(tipo: 'compromisso'))),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.7), blurRadius: 12, spreadRadius: 2)]),
                  child: const Icon(Icons.alarm, color: Colors.deepOrange, size: 28),
                ),
              ),
            ),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _currentUser != null
            ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('exames').orderBy('dataHora').snapshots()
            : null,
        builder: (context, snapshot) {
          if (_currentUser == null) return const Center(child: Text("Faça login para ver seus compromissos."));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum exame ou consulta agendado."));

          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] != 'Finalizado') {
              return true;
            }
            final dataFinalizado = (data['dataFinalizado'] as Timestamp?)?.toDate();
            return dataFinalizado != null && dataFinalizado.isAfter(sevenDaysAgo);
          }).toList();

          if (filteredDocs.isEmpty) return const Center(child: Text("Nenhum compromisso recente."));

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final dados = doc.data() as Map<String, dynamic>;
              final dataHora = (dados['dataHora'] as Timestamp).toDate();
              final bool isFinalizado = dados['status'] == 'Finalizado';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isFinalizado ? Colors.grey.shade200 : Colors.white,
                child: ListTile(
                  leading: Icon(dados['tipo'] == 'Exame' ? Icons.science_outlined : Icons.medical_services_outlined, color: isFinalizado ? Colors.grey : Colors.blueAccent),
                  title: Text("${dados['tipo']}: ${dados['especialidade']}", style: TextStyle(fontWeight: FontWeight.bold, decoration: isFinalizado ? TextDecoration.lineThrough : null)),
                  subtitle: Text("Local: ${dados['local']}\nData: ${DateFormat('dd/MM/yyyy HH:mm').format(dataHora)}"),
                  trailing: isFinalizado
                      ? const Text("Finalizado", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _finalizarCompromisso(doc.reference)),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _adicionarEditarCompromisso(doc)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _excluirCompromisso(doc)),
                          ],
                        ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarEditarCompromisso(),
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Compromisso',
      ),
    );
  }
}