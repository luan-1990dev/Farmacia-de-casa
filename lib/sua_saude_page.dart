import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SuaSaudePage extends StatefulWidget {
  const SuaSaudePage({super.key});

  @override
  State<SuaSaudePage> createState() => _SuaSaudePageState();
}

class _SuaSaudePageState extends State<SuaSaudePage> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  
  final TextEditingController _observacaoController = TextEditingController();
  
  String? _estadoDeSaude;
  double _nivelDeDor = 0;
  final List<String> _sintomasSelecionados = [];
  bool _fazExercicios = false;

  final List<String> _sintomasComuns = [
    'Dor de cabeça',
    'Tontura',
    'Cansaço',
    'Febre',
    'Falta de ar',
    'Náusea',
    'Tosse',
    'Dor no corpo',
  ];

  bool _isSaving = false;

  Map<String, dynamic> _gerarSugestao() {
    if (!_fazExercicios) {
      return {
        'sugestao': 'A prática regular de exercícios melhora a saúde geral. Considere começar com caminhadas leves!',
        'cor': Colors.lightBlue.shade50,
        'icone': Icons.directions_walk,
        'corIcone': Colors.lightBlue,
      };
    }
    if (_sintomasSelecionados.contains('Falta de ar')) {
      return {
        'sugestao': 'Falta de ar é um sintoma sério. Se persistir, procure atendimento médico imediatamente.',
        'cor': Colors.red.shade100,
        'icone': Icons.warning_amber_rounded,
        'corIcone': Colors.red,
      };
    }
    if ((_estadoDeSaude == 'Mal' || _estadoDeSaude == 'Muito mal') && _nivelDeDor > 7) {
      return {
        'sugestao': 'Seu estado requer atenção. Com dor intensa, é recomendável consultar um médico.',
        'cor': Colors.red.shade50,
        'icone': Icons.local_hospital,
        'corIcone': Colors.red,
      };
    }
    if (_sintomasSelecionados.contains('Febre') && _nivelDeDor > 5) {
      return {
        'sugestao': 'Febre com dor moderada/alta. Monitore a temperatura, hidrate-se e descanse.',
        'cor': Colors.orange.shade50,
        'icone': Icons.thermostat,
        'corIcone': Colors.orange,
      };
    }
    if (_estadoDeSaude == 'Excelente' || _estadoDeSaude == 'Bem') {
      return {
        'sugestao': 'Que ótimo! Continue mantendo seus hábitos saudáveis.',
        'cor': Colors.green.shade50,
        'icone': Icons.sentiment_satisfied_alt,
        'corIcone': Colors.green,
      };
    }
    return {
      'sugestao': 'Observe seus sintomas. Se não melhorar em 24h, procure orientação.',
      'cor': Colors.yellow.shade50,
      'icone': Icons.visibility,
      'corIcone': Colors.orangeAccent,
    };
  }

  Future<void> _salvarRegistro() async {
    if (_currentUser == null) return;
    if (_estadoDeSaude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione como está se sentindo.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_currentUser!.uid)
          .collection('historico_saude')
          .add({
        'dataHora': FieldValue.serverTimestamp(),
        'estado': _estadoDeSaude,
        'sintomas': _sintomasSelecionados,
        'nivelDor': _nivelDeDor,
        'fazExercicios': _fazExercicios,
        'observacao': _observacaoController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Diário de saúde atualizado!"), backgroundColor: Colors.green),
        );
        setState(() {
          _estadoDeSaude = null;
          _nivelDeDor = 0;
          _sintomasSelecionados.clear();
          _observacaoController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sugestao = _gerarSugestao();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua Saúde'),
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
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Como você está hoje?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: -4, // Reduz espaço vertical entre as linhas de chips
                      children: ['Excelente', 'Bem', 'Mais ou menos', 'Mal', 'Muito mal'].map((estado) => ChoiceChip(label: Text(estado), selected: _estadoDeSaude == estado, onSelected: (selected) => setState(() => _estadoDeSaude = selected ? estado : null))).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Sintomas:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: -4,
                      children: _sintomasComuns.map((sintoma) => FilterChip(label: Text(sintoma), selected: _sintomasSelecionados.contains(sintoma), onSelected: (selected) => setState(() => selected ? _sintomasSelecionados.add(sintoma) : _sintomasSelecionados.remove(sintoma)))).toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("Faz exercícios físicos regularmente?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text("(Pelo menos 3 vezes por semana)", style: TextStyle(fontSize: 12)),
                      value: _fazExercicios,
                      onChanged: (value) => setState(() => _fazExercicios = value),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nível de Dor:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_nivelDeDor.round()}/10', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    Slider(
                      value: _nivelDeDor,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: Colors.redAccent.withOpacity(0.3 + (_nivelDeDor/14)),
                      label: _nivelDeDor.round().toString(),
                      onChanged: (value) => setState(() => _nivelDeDor = value),
                    ),
                    TextField(controller: _observacaoController, decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'Algum detalhe extra?', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: sugestao['cor'], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                      child: Row(
                        children: [
                          Icon(sugestao['icone'], color: sugestao['corIcone']),
                          const SizedBox(width: 12),
                          Expanded(child: Text(sugestao['sugestao'], style: const TextStyle(fontSize: 14, color: Colors.black87))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.save), label: _isSaving ? const Text("Salvando...") : const Text("Registrar no Diário"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _isSaving ? null : _salvarRegistro)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Histórico Recente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('historico_saude').orderBy('dataHora', descending: true).limit(10).snapshots() : null,
              builder: (context, snapshot) {
                if (_currentUser == null) return const Text("Faça login para ver o histórico.");
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Nenhum registro ainda. Comece hoje!", textAlign: TextAlign.center)));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final dados = doc.data() as Map<String, dynamic>;
                    final data = (dados['dataHora'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final dataStr = DateFormat('dd/MM/yyyy HH:mm').format(data);
                    
                    final estado = dados['estado'] ?? '-';
                    final dor = dados['nivelDor'] ?? 0;
                    final sintomas = List<String>.from(dados['sintomas'] ?? []);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(radius: 20, backgroundColor: _getCorPorEstado(estado), child: Icon(_getIconePorEstado(estado), color: Colors.white, size: 20)),
                        title: Text("$estado - Dor: ${dor.round()}/10", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dataStr, style: const TextStyle(fontSize: 12, color: Colors.grey)), if (sintomas.isNotEmpty) Text("Sintomas: ${sintomas.join(', ')}", style: const TextStyle(fontSize: 13)), if (dados['observacao'] != null && dados['observacao'].isNotEmpty) Text("Obs: ${dados['observacao']}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13))]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                          onPressed: () => doc.reference.delete(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getCorPorEstado(String estado) {
    switch (estado) {
      case 'Excelente': return Colors.green;
      case 'Bem': return Colors.lightGreen;
      case 'Mais ou menos': return Colors.amber;
      case 'Mal': return Colors.orange;
      case 'Muito mal': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _getIconePorEstado(String estado) {
    if (estado == 'Excelente' || estado == 'Bem') return Icons.sentiment_satisfied_alt;
    if (estado == 'Muito mal') return Icons.sentiment_very_dissatisfied;
    return Icons.sentiment_neutral;
  }
}
