import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmacia_de_casa/notification_setup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExamesConsultasPage extends StatefulWidget {
  const ExamesConsultasPage({super.key});

  @override
  State<ExamesConsultasPage> createState() => _ExamesConsultasPageState();
}

class _ExamesConsultasPageState extends State<ExamesConsultasPage> {
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  // Função centralizada para agendar usando o serviço de debug
  Future<void> _agendarNotificacao(String docId, String titulo,
      DateTime dataHora) async {
    try {
      debugPrint("🚩 Chamando agendarNotificacaoGeral para o ID: $docId");
      // CORREÇÃO: Usando os parâmetros passados para a função
      await agendarNotificacaoGeral(
        id: docId,
        titulo: 'Hora do seu Exame / consulta' ,
        corpo: 'Compromisso: $titulo',
        dataHora: dataHora,
        tipo: 'exame',
      );
    } catch (e) {
      debugPrint("❌ Falha ao tentar chamar a função global: $e");
    }
  }

  Future<void> _cancelarNotificacao(String docId) async {
    final int safeId = docId.hashCode.abs();
    await flutterLocalNotificationsPlugin.cancel(safeId);
    debugPrint("🗑️ Alarme cancelado localmente para o ID: $safeId");
  }

  Future<void> _finalizarCompromisso(DocumentReference docRef) async {
    try {
      await docRef.update({
        'status': 'Finalizado',
        'dataFinalizado': FieldValue.serverTimestamp(),
      });
      await _cancelarNotificacao(docRef.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Compromisso finalizado!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erro ao finalizar: $e");
    }
  }

  void _adicionarEditarCompromisso([DocumentSnapshot? doc]) {
    final formKey = GlobalKey<FormState>();
    String? tipo = doc != null
        ? (doc.data() as Map<String, dynamic>)['tipo']
        : null;
    final especialidadeController = TextEditingController(
        text: doc != null ? (doc.data() as Map<String,
            dynamic>)['especialidade'] : '');
    final localController = TextEditingController(
        text: doc != null ? (doc.data() as Map<String, dynamic>)['local'] : '');
    DateTime? dataHora = doc != null
        ? ((doc.data() as Map<String, dynamic>)['dataHora'] as Timestamp)
        .toDate()
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  doc == null ? "Adicionar Compromisso" : "Editar Compromisso"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: tipo,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: ['Exame', 'Consulta']
                            .map((label) =>
                            DropdownMenuItem(value: label, child: Text(label)))
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => tipo = value),
                        validator: (value) =>
                        value == null
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      TextFormField(
                        controller: especialidadeController,
                        decoration: const InputDecoration(
                            labelText: 'Especialidade'),
                        validator: (value) =>
                        (value == null || value.isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      TextFormField(
                        controller: localController,
                        decoration: const InputDecoration(labelText: 'Local'),
                        validator: (value) =>
                        (value == null || value.isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      ListTile(
                        title: Text(dataHora == null
                            ? 'Selecionar Data/Hora'
                            : DateFormat('dd/MM/yyyy HH:mm').format(dataHora!)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final data = await showDatePicker(
                              context: context,
                              initialDate: dataHora ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                  const Duration(days: 1)),
                              lastDate: DateTime(2100));
                          if (data == null) return;

                          final hora = await showTimePicker(
                              context: context,
                              initialTime: dataHora != null
                                  ? TimeOfDay.fromDateTime(dataHora!)
                                  : TimeOfDay.now());
                          if (hora == null) return;

                          setDialogState(() {
                            dataHora = DateTime(
                                data.year, data.month, data.day, hora.hour,
                                hora.minute);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || dataHora == null) {
                      if (dataHora == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Por favor, selecione data e hora."),
                                backgroundColor: Colors.orange));
                      }
                      return;
                    }

                    final agora = DateTime.now();
                    if (dataHora!.isBefore(agora)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("A data do exame deve ser no futuro!"),
                          backgroundColor: Colors.red));
                      return;
                    }

                    debugPrint("💾 Iniciando processo de salvamento...");

                    final compromissoData = {
                      'tipo': tipo,
                      'especialidade': especialidadeController.text,
                      'local': localController.text,
                      'dataHora': Timestamp.fromDate(dataHora!),
                      'status': 'Pendente',
                      'userId': _currentUser?.uid,
                    };

                    try {
                      if (doc == null) {
                        final newDocRef = await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(_currentUser!.uid)
                            .collection('exames')
                            .add(compromissoData);

                        await _agendarNotificacao(newDocRef.id,
                            "${tipo!}: ${especialidadeController.text}",
                            dataHora!);
                      } else {
                        await doc.reference.update(compromissoData);
                        await _cancelarNotificacao(doc.id);
                        await _agendarNotificacao(doc.id,
                            "${tipo!}: ${especialidadeController.text}",
                            dataHora!);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Compromisso salvo com sucesso!"),
                              backgroundColor: Colors.green),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      debugPrint("❌ Erro ao salvar/agendar: $e");
                    }
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
        builder: (context) =>
            AlertDialog(
              title: const Text("Excluir"),
              content: const Text("Deseja excluir este compromisso?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text("Não")),
                TextButton(
                    onPressed: () async {
                      await _cancelarNotificacao(doc.id);
                      await doc.reference.delete();
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text(
                        "Sim", style: TextStyle(color: Colors.red))),
              ],
            ));
  }

  Widget _buildLista(List<DocumentSnapshot> docs, {required bool isHistory}) {
    if (docs.isEmpty)
      return const Center(child: Text("Nenhum compromisso encontrado."));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final dados = doc.data() as Map<String, dynamic>;
        final dataHora = (dados['dataHora'] as Timestamp).toDate();

        return Card(
          child: ListTile(
            onTap: () => _adicionarEditarCompromisso(doc),
            leading: Icon(
                dados['tipo'] == 'Exame' ? Icons.assignment : Icons
                    .medical_services,
                color: isHistory ? Colors.grey : Colors.blue),
            title: Text("${dados['tipo']}: ${dados['especialidade']}",
                style: TextStyle(
                    decoration: isHistory ? TextDecoration.lineThrough : null)),
            subtitle: Text(
                "${DateFormat('dd/MM/yyyy HH:mm').format(
                    dataHora)}\nLocal: ${dados['local']}"),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isHistory)
                  IconButton(
                    icon: const Icon(
                        Icons.check_circle_outline, color: Colors.green),
                    tooltip: "Concluir compromisso",
                    onPressed: () => _finalizarCompromisso(doc.reference),
                  ),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _excluirCompromisso(doc)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Exames e Consultas"),
          // CORREÇÃO: Removidos os botões de teste, limpeza e bug do array de actions
          actions: const [],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Pendentes"),
              Tab(text: "Histórico"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _currentUser != null
              ? FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_currentUser!.uid)
              .collection('exames')
              .orderBy('dataHora', descending: false)
              .snapshots()
              : null,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text("Erro ao carregar dados."));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data?.docs ?? [];
            final pendentes = allDocs
                .where((doc) =>
            (doc.data() as Map<String,
                dynamic>)['status'] == 'Pendente')
                .toList();
            final historico = allDocs
                .where((doc) =>
            (doc.data() as Map<String,
                dynamic>)['status'] == 'Finalizado')
                .toList();

            return TabBarView(
              children: [
                _buildLista(pendentes, isHistory: false),
                _buildLista(historico, isHistory: true),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _adicionarEditarCompromisso(),
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
