import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DosesHojePage extends StatefulWidget {
  const DosesHojePage({super.key});

  @override
  State<DosesHojePage> createState() => _DosesHojePageState();
}

class _DosesHojePageState extends State<DosesHojePage> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  final DateTime _hoje = DateTime.now();

  Future<void> _marcarStatusDose(String tratamentoId, String doseId, String status, String nomeMedicamento) async {
    if (_currentUser == null) return;

    final tratamentoRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_currentUser!.uid)
        .collection('tratamentos')
        .doc(tratamentoId);

    try {
      // Atualiza o status da dose
      await tratamentoRef.collection('doses').doc(doseId).update({
        'status': status,
        'dataConsumo': FieldValue.serverTimestamp(),
      });

      // Encontrar o medicamento correspondente para dar baixa no estoque
      final tratamentoDoc = await tratamentoRef.get();
      final nomeMedicamentoTratamento = tratamentoDoc.data()?['nome'];

      if (nomeMedicamentoTratamento != null) {
        final queryMedicamento = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_currentUser!.uid)
            .collection('medicamentos')
            .where('nome', isEqualTo: nomeMedicamentoTratamento)
            .limit(1)
            .get();

        if (queryMedicamento.docs.isNotEmpty) {
          final medicamentoId = queryMedicamento.docs.first.id;
          final medicamentoRef = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_currentUser!.uid)
              .collection('medicamentos')
              .doc(medicamentoId);

          await medicamentoRef.update({
            'quantidade': FieldValue.increment(-1),
          });

          final doc = await medicamentoRef.get();
          final data = doc.data();
          if (data != null && data.containsKey('quantidade')) {
            final novaQuantidade = data['quantidade'] as int;
            if (novaQuantidade <= 5 && novaQuantidade > 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Estoque baixo para $nomeMedicamento! Restam apenas $novaQuantidade unidades.'),
                    backgroundColor: Colors.orange.shade800,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            } else if (novaQuantidade <= 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Estoque de $nomeMedicamento esgotado!'),
                    backgroundColor: Colors.red.shade800,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {}); // Força a reconstrução da UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dose de $nomeMedicamento marcada como '$status'!"),
            duration: const Duration(seconds: 2),
            backgroundColor: status == 'Consumido' ? Colors.green : Colors.amber.shade800,
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao atualizar status da dose: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final startOfDay = DateTime(_hoje.year, _hoje.month, _hoje.day, 0, 0, 0);
    final endOfDay = DateTime(_hoje.year, _hoje.month, _hoje.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alarmes Agendados"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
        ),
      ),
      body: _currentUser == null
          ? const Center(child: Text("Faça login para ver suas doses."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(_currentUser!.uid)
                  .collection('tratamentos')
                  .snapshots(),
              builder: (context, snapshotTratamentos) {
                if (snapshotTratamentos.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshotTratamentos.hasData || snapshotTratamentos.data!.docs.isEmpty) {
                  return _buildEmptyState("Nenhum tratamento cadastrado.");
                }

                List<Future<QuerySnapshot>> futuresDoses = [];
                List<DocumentSnapshot> docsTratamentos = snapshotTratamentos.data!.docs;

                for (var docTrat in docsTratamentos) {
                  futuresDoses.add(docTrat.reference
                      .collection('doses')
                      .where('dataHora', isGreaterThanOrEqualTo: startOfDay)
                      .where('dataHora', isLessThanOrEqualTo: endOfDay)
                      .get());
                }

                return FutureBuilder<List<QuerySnapshot>>(
                  future: Future.wait(futuresDoses),
                  builder: (context, snapshotDoses) {
                    if (snapshotDoses.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Map<String, dynamic>> listaDosesDisplay = [];

                    if (snapshotDoses.hasData) {
                      for (int i = 0; i < snapshotDoses.data!.length; i++) {
                        var queryDoses = snapshotDoses.data![i];
                        var docTrat = docsTratamentos[i];
                        var dadosTrat = docTrat.data() as Map<String, dynamic>;

                        for (var docDose in queryDoses.docs) {
                          var dadosDose = docDose.data() as Map<String, dynamic>;
                          DateTime dataHora = (dadosDose['dataHora'] as Timestamp).toDate();
                          
                          listaDosesDisplay.add({
                            'idTratamento': docTrat.id,
                            'idDose': docDose.id,
                            'nome': dadosTrat['nome'] ?? 'Medicamento',
                            'observacao': dadosTrat['infoAdicional'], 
                            'dataHora': dataHora,
                            'status': dadosDose['status'],
                          });
                        }
                      }
                    }

                    if (listaDosesDisplay.isEmpty) {
                      return _buildEmptyState("Nenhuma dose agendada para hoje.");
                    }

                    listaDosesDisplay.sort((a, b) => (a['dataHora'] as DateTime).compareTo(b['dataHora'] as DateTime));

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: listaDosesDisplay.length,
                      itemBuilder: (context, index) {
                        final dose = listaDosesDisplay[index];
                        final DateTime horario = dose['dataHora'];
                        final String? status = dose['status'];
                        final String? observacao = dose['observacao'];
                        final bool semStatus = status == null;
                        final String horaFormatada = DateFormat('HH:mm').format(horario);
                        final bool atrasado = semStatus && horario.isBefore(DateTime.now());

                        Color statusColor = _getColorStatus(status, atrasado);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: statusColor, width: 1.5),
                          ),
                          color: _getCardColor(status, atrasado),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: statusColor,
                                      child: Icon(_getIconStatus(status), color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(dose['nome'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: status != null ? Colors.grey.shade700 : Colors.black87, decoration: status != null ? TextDecoration.lineThrough : null)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, size: 16, color: statusColor),
                                              const SizedBox(width: 4),
                                              Text(horaFormatada, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: statusColor)),
                                              if (atrasado) const Text(" (Atrasado)", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
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
                                if (semStatus)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton.icon(icon: const Icon(Icons.check, size: 18), label: const Text("Tomei"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _marcarStatusDose(dose['idTratamento'], dose['idDose'], "Consumido", dose['nome'])),
                                      OutlinedButton.icon(icon: const Icon(Icons.timer, size: 18), label: const Text("Com Atraso"), style: OutlinedButton.styleFrom(foregroundColor: Colors.amber.shade800, side: BorderSide(color: Colors.amber.shade800)), onPressed: () => _marcarStatusDose(dose['idTratamento'], dose['idDose'], "Atrasado", dose['nome'])),
                                    ],
                                  )
                                else
                                  Center(child: Text("Status: $status", style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade200),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getCardColor(String? status, bool atrasado) {
    if (status == 'Consumido') return Colors.green.shade50;
    if (status == 'Atrasado') return Colors.amber.shade50;
    if (atrasado) return Colors.red.shade50;
    return Colors.orange.shade50;
  }

  Color _getColorStatus(String? status, bool atrasado) {
    if (status == 'Consumido') return Colors.green;
    if (status == 'Atrasado') return Colors.amber.shade800;
    if (atrasado) return Colors.red;
    return Colors.orange;
  }

  IconData _getIconStatus(String? status) {
    if (status == 'Consumido') return Icons.check;
    if (status == 'Atrasado') return Icons.history;
    return Icons.medication;
  }
}
