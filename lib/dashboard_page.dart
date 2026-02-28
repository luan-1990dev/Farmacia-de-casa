import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDosesHojeCard(context),
            const SizedBox(height: 16),
            _buildAdherenceChartCard(context),
            const SizedBox(height: 16),
            _buildEstoqueCard(context),
            const SizedBox(height: 16),
            _buildExamesCard(context),
            const SizedBox(height: 16),
            _buildResidentesCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceChartCard(BuildContext context) {
    final hoje = DateTime.now();
    final umaSemanaAtras = hoje.subtract(const Duration(days: 6));
    final inicioDoPeriodo = DateTime(umaSemanaAtras.year, umaSemanaAtras.month, umaSemanaAtras.day);

    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance
              .collectionGroup('doses')
              .where('userId', isEqualTo: _currentUser!.uid)
              .where('dataHora', isGreaterThanOrEqualTo: inicioDoPeriodo)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (_currentUser == null) return const SizedBox.shrink();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }

        Map<int, double> dailyAdherence = {};
        for (int i = 0; i < 7; i++) {
          dailyAdherence[i] = 0.0;
        }

        if (snapshot.hasData) {
          final dosesDaSemana = snapshot.data!.docs;
          Map<int, int> totalDosesPorDia = {};
          Map<int, int> dosesTomadasPorDia = {};

          for (var doseDoc in dosesDaSemana) {
            final dose = doseDoc.data() as Map<String, dynamic>;
            final dataHora = (dose['dataHora'] as Timestamp).toDate();
            final diaDaSemana = dataHora.weekday % 7;

            totalDosesPorDia.update(diaDaSemana, (value) => value + 1, ifAbsent: () => 1);
            if (dose['tomado'] == true) {
              dosesTomadasPorDia.update(diaDaSemana, (value) => value + 1, ifAbsent: () => 1);
            }
          }

          totalDosesPorDia.forEach((dia, total) {
            final tomadas = dosesTomadasPorDia[dia] ?? 0;
            dailyAdherence[dia] = (tomadas / total) * 100;
          });
        }

        return _buildDashboardCard(
          title: "Adesão nos Últimos 7 Dias",
          color: Colors.lightBlue,
          icon: Icons.bar_chart,
          child: SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final dias = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                        return Text(dias[value.toInt()]);
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: dailyAdherence.entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: Colors.lightBlueAccent,
                        width: 15,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildDosesHojeCard(BuildContext context) {
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day, 0, 0, 0);
    final fimDoDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('medicamentos').snapshots()
          : null,
      builder: (context, snapshotMedicamentos) {
        if (_currentUser == null) return const SizedBox.shrink();
        if (snapshotMedicamentos.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }

        final medicamentos = snapshotMedicamentos.data?.docs ?? [];
        if (medicamentos.isEmpty) {
          return _buildDashboardCard(
            title: 'Doses de Hoje',
            color: Colors.green,
            icon: Icons.check_circle_outline,
            child: const Center(child: Text("Nenhum medicamento cadastrado.")),
          );
        }

        List<Future<QuerySnapshot>> doseFutures = [];
        for (var medDoc in medicamentos) {
          doseFutures.add(medDoc.reference.collection('doses').where('dataHora', isGreaterThanOrEqualTo: inicioDoDia).where('dataHora', isLessThanOrEqualTo: fimDoDia).get());
        }

        return FutureBuilder<List<QuerySnapshot>>(
          future: Future.wait(doseFutures),
          builder: (context, snapshotDoses) {
            if (snapshotDoses.connectionState == ConnectionState.waiting) {
              return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
            }

            int totalDoses = 0;
            int dosesTomadas = 0;

            if (snapshotDoses.hasData) {
              for (var query in snapshotDoses.data!) {
                totalDoses += query.docs.length;
                dosesTomadas += query.docs.where((d) => (d.data() as Map<String, dynamic>)['tomado'] == true).length;
              }
            }

            final porcentagem = totalDoses > 0 ? (dosesTomadas / totalDoses) * 100 : 0.0;

            return _buildDashboardCard(
              title: 'Doses de Hoje',
              color: Colors.green,
              icon: Icons.check_circle_outline,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: Colors.green.shade400,
                              value: porcentagem,
                              title: '${porcentagem.toStringAsFixed(0)}%',
                              radius: 30,
                              titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              color: Colors.grey.shade300,
                              value: 100 - porcentagem,
                              title: '',
                              radius: 25,
                            ),
                          ],
                          centerSpaceRadius: 15,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$dosesTomadas de $totalDoses tomadas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Text('Progresso do dia', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEstoqueCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('medicamentos').snapshots() : null,
      builder: (context, snapshot) {
         if (_currentUser == null) return const SizedBox.shrink();
         if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

         final medicamentos = snapshot.data!.docs;
         final total = medicamentos.length;
         final vencidos = medicamentos.where((doc) {
            final data = (doc.data() as Map<String, dynamic>)['validade'] as Timestamp?;
            return data != null && data.toDate().isBefore(DateTime.now());
         }).length;
         final proxVencimento = medicamentos.where((doc) {
            final data = (doc.data() as Map<String, dynamic>)['validade'] as Timestamp?;
            return data != null && !data.toDate().isBefore(DateTime.now()) && data.toDate().isBefore(DateTime.now().add(const Duration(days: 30)));
         }).length;

        return _buildDashboardCard(
          title: 'Resumo do Estoque',
          color: Colors.orange,
          icon: Icons.inventory_2_outlined,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn('Total', total.toString(), Colors.blue),
              _buildInfoColumn('Próx. Venc.', proxVencimento.toString(), Colors.orange),
              _buildInfoColumn('Vencidos', vencidos.toString(), Colors.red),
            ],
          )
        );
      },
    );
  }

  Widget _buildExamesCard(BuildContext context) {
      return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_currentUser!.uid)
              .collection('exames')
              .where('dataHora', isGreaterThanOrEqualTo: DateTime.now())
              .orderBy('dataHora')
              .limit(2)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (_currentUser == null || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildDashboardCard(title: 'Próximos Exames', color: Colors.purple, icon: Icons.calendar_today, child: const Center(child: Text('Nenhum exame agendado.')));
        }

        return _buildDashboardCard(
          title: 'Próximos Exames',
          color: Colors.purple,
          icon: Icons.calendar_today,
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final dados = doc.data() as Map<String, dynamic>;
              final data = (dados['dataHora'] as Timestamp).toDate();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.event, color: Colors.purple),
                title: Text(dados['tipo'] ?? 'Exame', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("${DateFormat('dd/MM/yyyy').format(data)} às ${DateFormat('HH:mm').format(data)}"),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildResidentesCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
       stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('residentes').snapshots() : null,
       builder: (context, snapshot) {
         if(_currentUser == null || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

         return _buildDashboardCard(
           title: 'Residentes',
           color: Colors.teal,
           icon: Icons.people_outline,
           child: SizedBox(
             height: 50,
             child: ListView.builder(
               scrollDirection: Axis.horizontal,
               itemCount: snapshot.data!.docs.length,
               itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final nome = (doc.data() as Map<String, dynamic>)['nome'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Chip(
                      avatar: CircleAvatar(child: Text(nome[0].toUpperCase())),
                      label: Text(nome),
                    ),
                  );
               },
             ),
           ),
         );
       },
    );
  }

  Widget _buildDashboardCard({required String title, required Color color, required IconData icon, required Widget child}){
     return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}