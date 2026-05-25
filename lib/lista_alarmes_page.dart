import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'notification_setup.dart';

class ListaAlarmesPage extends StatefulWidget {
  final String tipo; // 'medicamento' ou 'exame'
  const ListaAlarmesPage({super.key, required this.tipo});

  @override
  State<ListaAlarmesPage> createState() => _ListaAlarmesPageState();
}

class _ListaAlarmesPageState extends State<ListaAlarmesPage> {
  List<PendingNotificationRequest> _notificacoesVisiveis = [];

  // Gera cores dinâmicas para os ícones baseadas no nome do remédio
  Color _getMedicamentoColor(String nome) {
    final List<Color> baseColors = [
      Colors.blue.shade700,
      Colors.teal.shade700,
      Colors.purple.shade700,
      Colors.indigo.shade700,
      Colors.cyan.shade800,
      Colors.deepPurple.shade700,
    ];
    final int index = nome.toLowerCase().hashCode.abs() % baseColors.length;
    return baseColors[index];
  }

  // Busca as notificações agendadas no sistema operacional
  Future<List<PendingNotificationRequest>> _carregarNotificacoes() async {
    final todasAsNotificacoes = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    final agora = DateTime.now();

    final notificacoesFiltradas = todasAsNotificacoes.where((req) {
      if (req.payload == null) return false;
      try {
        final data = jsonDecode(req.payload!);
        // Filtra apenas o tipo solicitado (medicamento ou exame)
        if (data['type'] != widget.tipo) return false;

        // Verifica se a data agendada é futura para evitar exibir lixo do sistema
        if (data['dataHora'] != null) {
          final dataAlarme = DateTime.parse(data['dataHora']).toLocal();
          return dataAlarme.isAfter(agora);
        }
        return true;
      } catch (e) {
        return false;
      }
    }).toList();

    // Ordena a lista cronologicamente (o mais próximo primeiro)
    notificacoesFiltradas.sort((a, b) {
      try {
        final dataA = DateTime.parse(jsonDecode(a.payload!)['dataHora']);
        final dataB = DateTime.parse(jsonDecode(b.payload!)['dataHora']);
        return dataA.compareTo(dataB);
      } catch (_) {
        return 0;
      }
    });

    _notificacoesVisiveis = notificacoesFiltradas;
    return notificacoesFiltradas;
  }

  void _refresh() => setState(() {});

  Future<void> _cancelarNotificacao(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lembrete removido com sucesso."), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tituloTela = widget.tipo == 'medicamento' ? "Próximas Doses" : "Meus Compromissos";

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloTela),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final agora = DateTime.now();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateFormat('HH:mm').format(agora),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(DateFormat('EEEE, dd/MM', 'pt_BR').format(agora),
                        style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<PendingNotificationRequest>>(
          future: _carregarNotificacoes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final notificacoes = snapshot.data ?? [];

            if (notificacoes.isEmpty) {
              return const Center(
                child: Text("Nenhum lembrete para os próximos dias.", style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notificacoes.length,
              itemBuilder: (context, index) => _buildMedicamentoCard(notificacoes[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMedicamentoCard(PendingNotificationRequest notificacao) {
    String nome = 'Medicamento';
    String horaStr = "--:--";
    String dataStr = "--/--/--";

    try {
      final payloadData = jsonDecode(notificacao.payload!);
      // Extração prioritária do título e data salvos no momento do agendamento
      nome = payloadData['titulo'] ?? payloadData['nome'] ?? "Remédio";
      String? dataRaw = payloadData['dataHora'] ?? payloadData['data_hora'];

      if (payloadData['dataHora'] != null) {
        final dt = DateTime.parse(payloadData['dataHora']).toLocal();
        horaStr = DateFormat('HH:mm').format(dt);
        dataStr = DateFormat('dd/MM/yy').format(dt);
      }
    } catch (e) {
      debugPrint("Erro ao decodificar alarme: $e");
    }

    final Color medColor = _getMedicamentoColor(nome);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: medColor.withOpacity(0.1),
          child: Icon(widget.tipo == 'medicamento' ? Icons.medication : Icons.calendar_today, color: medColor),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "A dose será às $horaStr do dia $dataStr.",
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _cancelarNotificacao(notificacao.id),
        ),
      ),
    );
  }
}