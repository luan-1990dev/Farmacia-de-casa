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
import 'package:share_plus/share_plus.dart';
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
        'Hora do Medicamento',
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

  void _compartilharCompromisso(Map<String, dynamic> dados) {
    final String dataHora = DateFormat('dd/MM/yyyy HH:mm').format((dados['dataHora'] as Timestamp).toDate());
    final String mensagem = 
      "🔔 *Lembrete de Saúde - Farmácia de Casa*\n\n"
      "📍 *Tipo:* ${dados['tipo']}\n"
      "👨‍⚕️ *Especialidade:* ${dados['especialidade']}\n"
      "🗓️ *Data e Hora:* $dataHora\n"
      "🏥 *Local:* ${dados['local']}\n\n"
      "Enviado pelo app Farmácia de Casa.";

    Share.share(mensagem);
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

  Widget _buildEmptyState(String message, {bool isHistory = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isHistory ? Icons.history : Icons.event_available_outlined, size: 100, color: Colors.blue.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              isHistory ? "Histórico Vazio" : "Tudo sob controle!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (!isHistory) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _adicionarEditarCompromisso(),
                icon: const Icon(Icons.add),
                label: const Text("Agendar Compromisso"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<QuerySnapshot>(
        stream: _currentUser != null
            ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('exames').orderBy('dataHora').snapshots()
            : null,
        builder: (context, snapshot) {
          if (_currentUser == null) return const Scaffold(body: Center(child: Text("Faça login para ver seus compromissos.")));
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

          final allDocs = snapshot.data?.docs ?? [];
          final pendentes = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] != 'Finalizado').toList();
          final historico = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Finalizado').toList();

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
              bottom: const TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.upcoming), text: "Pendentes"),
                  Tab(icon: Icon(Icons.history), text: "Histórico"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildLista(pendentes, false),
                _buildLista(historico, true),
              ],
            ),
            floatingActionButton: Builder(
              builder: (context) {
                return FloatingActionButton(
                  onPressed: () => _adicionarEditarCompromisso(),
                  child: const Icon(Icons.add),
                  tooltip: 'Adicionar Compromisso',
                );
              }
            ),
          );
        },
      ),
    );
  }

  Widget _buildLista(List<DocumentSnapshot> docs, bool isHistory) {
    if (docs.isEmpty) {
      return _buildEmptyState(
        isHistory ? "Você ainda não finalizou nenhum compromisso." : "Você não possui compromissos agendados.",
        isHistory: isHistory,
      );
    }

    return ListView.builder(
      itemCount: docs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final dados = doc.data() as Map<String, dynamic>;
        final dataHora = (dados['dataHora'] as Timestamp).toDate();
        final bool isFinalizado = dados['status'] == 'Finalizado';

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFinalizado ? Colors.grey.shade300 : Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(dados['tipo'] == 'Exame' ? Icons.science : Icons.medical_services, color: isFinalizado ? Colors.grey : Colors.blue.shade800),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "${dados['tipo']}: ${dados['especialidade']}",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isFinalizado ? Colors.grey : Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, size: 20, color: isFinalizado ? Colors.grey : Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Flexible(child: Text(dados['local'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 20, color: isFinalizado ? Colors.grey : Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(dataHora),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isFinalizado) ...[
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.blueGrey),
                        tooltip: 'Compartilhar',
                        onPressed: () => _compartilharCompromisso(dados),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                        tooltip: 'Finalizar',
                        onPressed: () => _finalizarCompromisso(doc.reference),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                        tooltip: 'Editar',
                        onPressed: () => _adicionarEditarCompromisso(doc),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Excluir',
                      onPressed: () => _excluirCompromisso(doc),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
