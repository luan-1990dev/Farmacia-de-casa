import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'notification_setup.dart';

class ListaAlarmesPage extends StatefulWidget {
  final String tipo;

  const ListaAlarmesPage({super.key, required this.tipo});

  @override
  State<ListaAlarmesPage> createState() => _ListaAlarmesPageState();
}

class _ListaAlarmesPageState extends State<ListaAlarmesPage> {
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  List<PendingNotificationRequest> _notificacoesVisiveis = []; 
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Color _getMedicamentoColor(String nome) {
    final List<Color> baseColors = [
      Colors.blue.shade700, Colors.teal.shade700, Colors.purple.shade700,
      Colors.indigo.shade700, Colors.brown.shade700, Colors.cyan.shade800,
      Colors.deepPurple.shade700, Colors.pink.shade700,
    ];
    final int index = nome.toLowerCase().hashCode.abs() % baseColors.length;
    return baseColors[index];
  }

  Future<List<PendingNotificationRequest>> _carregarNotificacoes() async {
    // BUSCA TODAS AS NOTIFICAÇÕES REGISTRADAS NO ANDROID
    final todasAsNotificacoes = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    final agora = DateTime.now();
    final limiteFuturo = agora.add(const Duration(days: 3));

    debugPrint("--- [DEBUG NOTIFICAÇÕES] INÍCIO DO SCAN ---");
    debugPrint("Total de alarmes encontrados no sistema Android: ${todasAsNotificacoes.length}");

    final notificacoesFiltradas = todasAsNotificacoes.where((req) {
      if (req.payload == null) {
        debugPrint("Alarme ID ${req.id}: Ignorado (Payload nulo)");
        return false;
      }
      try {
        final data = jsonDecode(req.payload!);
        debugPrint("Alarme ID ${req.id}: Payload = $data");

        if (data['type'] != widget.tipo) {
          debugPrint("Alarme ID ${req.id}: Ignorado (Tipo '${data['type']}' não é '${widget.tipo}')");
          return false;
        }

        final dataAlarme = DateTime.parse(data['dataHora']).toLocal();
        final bool noPrazo = dataAlarme.isAfter(agora) && dataAlarme.isBefore(limiteFuturo);
        
        if (!noPrazo) {
          debugPrint("Alarme ID ${req.id}: Agendado para $dataAlarme (Fora do intervalo de 3 dias)");
        }

        return noPrazo;
      } catch (e) {
        debugPrint("Alarme ID ${req.id}: ERRO AO LER DADOS: $e");
        return false;
      }
    }).toList();

    debugPrint("Total de alarmes que serão exibidos na tela: ${notificacoesFiltradas.length}");
    debugPrint("--- [DEBUG NOTIFICAÇÕES] FIM DO SCAN ---");

    notificacoesFiltradas.sort((a, b) {
      DateTime? dataA, dataB;
      try { dataA = DateTime.parse(jsonDecode(a.payload!)['dataHora']).toLocal(); } catch (_) {}
      try { dataB = DateTime.parse(jsonDecode(b.payload!)['dataHora']).toLocal(); } catch (_) {}
      if (dataA == null || dataB == null) return 0;
      return dataA.compareTo(dataB);
    });
    
    _notificacoesVisiveis = notificacoesFiltradas;
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

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _notificacoesVisiveis.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        for (var req in _notificacoesVisiveis) {
          _selectedIds.add(req.id);
        }
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _cancelarNotificacao(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lembrete cancelado."), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
      _refreshNotificacoes();
    }
  }

  Future<void> _cancelarSelecionados() async {
    final int count = _selectedIds.length;
    final listaParaRemover = List<int>.from(_selectedIds);

    for (int id in listaParaRemover) {
      await flutterLocalNotificationsPlugin.cancel(id);
    }

    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$count lembrete(s) removido(s)."), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
      _refreshNotificacoes();
    }
  }

  Future<DocumentSnapshot?> _getFirestoreDoc(String? docId) {
    if (_currentUser == null || docId == null) return Future.value(null);
    String collection = widget.tipo == 'medicamento' ? 'tratamentos' : 'exames';
    return FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection(collection).doc(docId).get();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.tipo == 'medicamento' ? "Próximas Doses" : "Meus Compromissos";
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? "${_selectedIds.length} selecionado(s)" : titulo),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        actions: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: StreamBuilder(
                stream: Stream.periodic(const Duration(minutes: 1)),
                builder: (context, snapshot) {
                  final agora = DateTime.now();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('HH:mm').format(agora), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(DateFormat('EEEE, dd/MM', 'pt_BR').format(agora), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(_selectedIds.length == _notificacoesVisiveis.length ? Icons.deselect : Icons.select_all), 
              onPressed: _toggleSelectAll,
            ),
            IconButton(icon: const Icon(Icons.delete), onPressed: _cancelarSelecionados),
          ]
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshNotificacoes(),
        child: FutureBuilder<List<PendingNotificationRequest>>(
          future: _carregarNotificacoes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final notificacoes = snapshot.data ?? [];
            if (notificacoes.isEmpty) {
              return const Center(child: Text("Nenhum lembrete para os próximos dias.", style: TextStyle(color: Colors.grey)));
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
    DateTime? dataHora;
    try {
      final payloadData = jsonDecode(notificacao.payload!);
      docId = payloadData['id'] ?? payloadData['docId'] ?? payloadData['localId'];
      dataHora = DateTime.parse(payloadData['dataHora']).toLocal();
    } catch (e) {}

    return FutureBuilder<DocumentSnapshot?>(
      future: _getFirestoreDoc(docId),
      builder: (context, snapshot) {
        String nome = '...';
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
          nome = snapshot.data!.get('nome') ?? 'Medicamento';
        }
        
        final isSelected = _selectedIds.contains(notificacao.id);
        final Color medColor = _getMedicamentoColor(nome);

        final horaStr = dataHora != null ? DateFormat('HH:mm').format(dataHora) : "...";
        final dataStr = dataHora != null ? DateFormat('dd/MM/yy').format(dataHora) : "...";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onLongPress: () => _toggleSelection(notificacao.id),
            onTap: () => _isSelectionMode ? _toggleSelection(notificacao.id) : null,
            selected: isSelected,
            leading: CircleAvatar(backgroundColor: medColor.withOpacity(0.1), child: Icon(widget.tipo == 'medicamento' ? Icons.medication : Icons.event, color: medColor)),
            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("A dose será às $horaStr do dia $dataStr."),
            trailing: _isSelectionMode 
              ? Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: Colors.blue)
              : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _cancelarNotificacao(notificacao.id)),
          ),
        );
      },
    );
  }
}
