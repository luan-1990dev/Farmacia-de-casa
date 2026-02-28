import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class ListaAlarmesPage extends StatefulWidget {
  final String tipo;

  const ListaAlarmesPage({super.key, required this.tipo});

  @override
  State<ListaAlarmesPage> createState() => _ListaAlarmesPageState();
}

class _ListaAlarmesPageState extends State<ListaAlarmesPage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<List<PendingNotificationRequest>> _carregarNotificacoes() async {
    final todasAsNotificacoes =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    final notificacoesFiltradas = todasAsNotificacoes.where((req) {
      if (req.payload == null) return false;
      try {
        final data = jsonDecode(req.payload!);
        return data.containsKey('type') && data['type'] == widget.tipo;
      } catch (e) {
        return false;
      }
    }).toList();

    notificacoesFiltradas.sort((a, b) {
      DateTime? dataA, dataB;
      try { dataA = a.payload != null ? DateTime.parse(jsonDecode(a.payload!)['dataHora']) : null; } catch (_) {}
      try { dataB = b.payload != null ? DateTime.parse(jsonDecode(b.payload!)['dataHora']) : null; } catch (_) {}
      if (dataA == null && dataB == null) return 0;
      if (dataA == null) return 1;
      if (dataB == null) return -1;
      return dataA.compareTo(dataB);
    });
    
    return notificacoesFiltradas;
  }
  
  void _refreshNotificacoes() {
    setState(() {}); 
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _cancelarNotificacao(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lembrete cancelado."), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
      _refreshNotificacoes();
    }
  }

  Future<void> _cancelarSelecionados() async {
    final int count = _selectedIds.length;
    for (int id in _selectedIds) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }
    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$count lembrete(s) cancelado(s)."), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    }
  }

  Future<DocumentSnapshot?> _getFirestoreDoc(String docId) {
    if (_currentUser == null) return Future.value(null);
    String collection = widget.tipo == 'medicamento' ? 'tratamentos' : 'exames';
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_currentUser!.uid)
        .collection(collection)
        .doc(docId)
        .get();
  }

  Color _getCardColor() => Colors.orange.shade50;
  Color _getStatusColor() => Colors.orange;

  @override
  Widget build(BuildContext context) {
    final titulo = widget.tipo == 'medicamento' ? "Alarmes Agendados" : "Lembretes de Compromissos";
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? "${_selectedIds.length} selecionado(s)" : titulo),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        actions: [
          if (!_isSelectionMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(minutes: 1)),
                  builder: (context, snapshot) {
                    return Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.white38),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('HH:mm').format(DateTime.now()),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white38),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          if (_isSelectionMode)
            IconButton(icon: const Icon(Icons.delete), tooltip: "Cancelar Selecionados", onPressed: _cancelarSelecionados),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshNotificacoes(),
        child: FutureBuilder<List<PendingNotificationRequest>>(
          future: _carregarNotificacoes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erro ao carregar alarmes: ${snapshot.error}"));
            }
            final notificacoes = snapshot.data ?? [];
            if (notificacoes.isEmpty) {
              return Center(
                child: ListView( 
                  children: [ 
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    const Icon(Icons.alarm_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("Nenhum lembrete pendente.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notificacoes.length,
              itemBuilder: (context, index) {
                final notificacao = notificacoes[index];
                return _buildMedicamentoCard(notificacao);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMedicamentoCard(PendingNotificationRequest notificacao) {
    String? docId;
    if (notificacao.payload != null) {
      try {
        final payloadData = jsonDecode(notificacao.payload!);
        docId = payloadData['id'] ?? payloadData['docId'];
      } catch (e) {}
    }

    if (docId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot?>(
      future: _getFirestoreDoc(docId),
      builder: (context, snapshot) {
        String nome = 'Lembrete';
        DateTime? dataHora;
        String? observacao;

        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nome = data['nome'] ?? nome;
          observacao = data['infoAdicional'];
        }

        if (notificacao.payload != null) {
          try {
            dataHora = DateTime.parse(jsonDecode(notificacao.payload!)['dataHora']);
          } catch (e) {}
        }
        
        final isSelected = _selectedIds.contains(notificacao.id);
        final statusColor = _getStatusColor();

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: isSelected ? Colors.blueAccent : statusColor, width: isSelected ? 2.5 : 1.5),
          ),
          color: isSelected ? Colors.blue.shade50 : _getCardColor(),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onLongPress: () => _toggleSelection(notificacao.id),
            onTap: () => _isSelectionMode ? _toggleSelection(notificacao.id) : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor,
                        child: Icon(widget.tipo == 'medicamento' ? Icons.medication_outlined : Icons.calendar_today, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            if (dataHora != null)
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yy HH:mm').format(dataHora),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: statusColor),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (observacao != null && observacao.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("Obs: $observacao", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                    ),
                  const SizedBox(height: 12),
                  if (!_isSelectionMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text("Cancelar Alarme"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                          onPressed: () => _cancelarNotificacao(notificacao.id),
                        )
                      ],
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
