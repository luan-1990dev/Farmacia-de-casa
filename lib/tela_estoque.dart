import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farmacia_de_casa/scanner_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ControleEstoquePage extends StatefulWidget {
  const ControleEstoquePage({super.key});

  @override
  State<ControleEstoquePage> createState() => _ControleEstoquePageState();
}

enum OrdemOrdenacao { nome, validade, quantidade }

class _ControleEstoquePageState extends State<ControleEstoquePage> with SingleTickerProviderStateMixin {
  OrdemOrdenacao _ordemAtual = OrdemOrdenacao.nome;
  late TabController _tabController;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onDatePicked) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      onDatePicked(picked);
    }
  }

  void _showGuiaDescarte(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Guia de Descarte Correto"),
        content: const Text("Medicamentos vencidos não devem ser jogados no lixo comum ou no vaso sanitário. Procure uma farmácia ou posto de saúde que realize a coleta para o descarte correto e seguro. Não reutilize antibiótico de um tratamento anterior."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Entendi")),
        ],
      ),
    );
  }
  
  Widget _buildNivelButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? color : Colors.grey,
        side: BorderSide(color: isSelected ? color : Colors.grey.shade400, width: isSelected ? 2 : 1),
        backgroundColor: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Future<void> _showAddMedicamentoDialog({String? ean}) async {
    final nomeController = TextEditingController();
    final dosagemController = TextEditingController();
    final quantidadeController = TextEditingController();
    final observacaoController = TextEditingController();
    final eanController = TextEditingController(text: ean);
    String? nivelEstoque;
    DateTime? dataValidade;
    bool usoContinuo = false;
    bool isAntibiotico = false;
    String? validationError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Adicionar ao Estoque"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(validationError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: "Nome do Medicamento*")),
                    TextFormField(controller: dosagemController, decoration: const InputDecoration(labelText: "Dosagem (mg/ml)*")),
                    TextFormField(controller: quantidadeController, decoration: const InputDecoration(labelText: "Quantidade (unidade)*", hintText: "Apenas para pílulas, etc."), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    Text("Quantidade (Nível Estimado)", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
                    Text("Para frascos, xaropes, etc.", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNivelButton(context, label: "100% a 60%", icon: Icons.medication_liquid, color: Colors.green, isSelected: nivelEstoque == "100% a 60%", onPressed: () => setDialogState(() => nivelEstoque = "100% a 60%")),
                        const SizedBox(height: 8),
                        _buildNivelButton(context, label: "60% a 20%", icon: Icons.medication_liquid, color: Colors.amber.shade700, isSelected: nivelEstoque == "60% a 20%", onPressed: () => setDialogState(() => nivelEstoque = "60% a 20%")),
                        const SizedBox(height: 8),
                        _buildNivelButton(context, label: "- 20%", icon: Icons.medication_liquid, color: Colors.orange.shade800, isSelected: nivelEstoque == "- 20%", onPressed: () => setDialogState(() => nivelEstoque = "- 20%")),
                      ],
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dataValidade == null ? "Validade (Mês/Ano)*" : "Validade: ${DateFormat('dd/MM/yyyy').format(dataValidade!)}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, dataValidade, (picked) => setDialogState(() => dataValidade = picked)),
                    ),
                    TextFormField(
                      controller: observacaoController,
                      decoration: const InputDecoration(labelText: "Observações", hintText: "Ex: guardar na geladeira"),
                      maxLength: 60,
                    ),
                    TextField(controller: eanController, decoration: const InputDecoration(labelText: "Código de Barras (opcional)"), enabled: ean == null),
                    SwitchListTile(title: const Text("Uso Contínuo"), value: usoContinuo, onChanged: (value) => setDialogState(() => usoContinuo = value)),
                    SwitchListTile(title: const Text("É Antibiótico?"), value: isAntibiotico, onChanged: (value) => setDialogState(() => isAntibiotico = value)),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.black),
                      onPressed: () async {
                        if (nomeController.text.isEmpty || dosagemController.text.isEmpty || dataValidade == null) {
                          setDialogState(() => validationError = "Todos os campos com * são obrigatórios");
                          return;
                        }

                        final dadosParaSalvar = {
                          'nome': nomeController.text,
                          'quantidade': int.tryParse(quantidadeController.text) ?? 0,
                          'nivelEstoque': nivelEstoque,
                          'dosagem': dosagemController.text,
                          'observacao': observacaoController.text,
                          'validade': dataValidade,
                          'usoContinuo': usoContinuo,
                          'isAntibiotico': isAntibiotico,
                          'ean': eanController.text.trim().isNotEmpty ? eanController.text.trim() : null,
                          'criadoEm': FieldValue.serverTimestamp(),
                          'userId': _currentUser!.uid,
                        };

                        await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('medicamentos').add(dadosParaSalvar);

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medicamento adicionado!"), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("Salvar"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _scanAndAdd() async {
    final codigo = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
    if (codigo != null && mounted) {
      _showAddMedicamentoDialog(ean: codigo);
    }
  }

  List<DocumentSnapshot> _ordenarLista(List<DocumentSnapshot> docs) {
    List<DocumentSnapshot> listaOrdenada = List.from(docs);
    listaOrdenada.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_ordemAtual) {
        case OrdemOrdenacao.validade:
          final valA = dataA['validade'] as Timestamp?;
          final valB = dataB['validade'] as Timestamp?;
          if (valA == null) return 1; if (valB == null) return -1;
          return valA.compareTo(valB);
        case OrdemOrdenacao.quantidade:
          final qtdA = (dataA['quantidade'] as num?) ?? 0;
          final qtdB = (dataB['quantidade'] as num?) ?? 0;
          return qtdA.compareTo(qtdB);
        default:
          final nomeA = (dataA['nome'] ?? '').toString().toLowerCase();
          final nomeB = (dataB['nome'] ?? '').toString().toLowerCase();
          return nomeA.compareTo(nomeB);
      }
    });
    return listaOrdenada;
  }

  void _confirmarExclusao(DocumentReference docRef, String nome) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Confirmar Exclusão"), content: Text("Deseja realmente excluir o medicamento $nome?"), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          TextButton(onPressed: () { docRef.delete(); Navigator.of(context).pop(); }, child: const Text("Excluir", style: TextStyle(color: Colors.red)))]));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text("Estoque")), body: const Center(child: Text("Faça login para ver seu estoque")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciamento de estoque"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        bottom: TabBar(controller: _tabController, indicatorColor: Colors.white, tabs: const [Tab(text: "Estoque Completo"), Tab(text: "Alertas de Vencimento")]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: PopupMenuButton<OrdemOrdenacao>(
                onSelected: (OrdemOrdenacao result) => setState(() => _ordemAtual = result),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<OrdemOrdenacao>>[
                  const PopupMenuItem<OrdemOrdenacao>(value: OrdemOrdenacao.nome, child: Text('Por Nome')),
                  const PopupMenuItem<OrdemOrdenacao>(value: OrdemOrdenacao.validade, child: Text('Por Validade')),
                  const PopupMenuItem<OrdemOrdenacao>(value: OrdemOrdenacao.quantidade, child: Text('Por Quantidade')),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 3)],
                  ),
                  child: Icon(Icons.sort, color: Colors.blue.shade800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('medicamentos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
          final allDocs = snapshot.data?.docs ?? [];

          final listaOrdenada = _ordenarLista(allDocs);

          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListaMedicamentos(listaOrdenada),
                    _buildListaMedicamentos(listaOrdenada.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final validade = (data['validade'] as Timestamp?)?.toDate();
                      if (validade == null) return false;
                      final diff = validade.difference(DateTime.now()).inDays;
                      return diff <= 30;
                    }).toList(), isAlerta: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
       persistentFooterButtons: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("Ler codigo de barras"),
                  onPressed: _scanAndAdd,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Adicionar Manual"),
                  onPressed: () => _showAddMedicamentoDialog(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildListaMedicamentos(List<DocumentSnapshot> lista, {bool isAlerta = false}) {
    if (lista.isEmpty) return const Center(child: Text("Nenhum item aqui."));
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final doc = lista[index];
        final data = doc.data() as Map<String, dynamic>;
        final dosagem = data['dosagem'] as String?;
        final nivelEstoque = data['nivelEstoque'] as String?;
        final quantidade = (data['quantidade'] as num?)?.toInt() ?? 0;
        final observacao = data['observacao'] as String?;
        final validade = data['validade'] as Timestamp?;
        final isAntibiotico = data['isAntibiotico'] ?? false;
        final vencido = validade != null && validade.toDate().isBefore(DateTime.now());

        bool prestesAVencer = false;
        if (validade != null && !vencido) {
          final diff = validade.toDate().difference(DateTime.now()).inDays;
          prestesAVencer = diff <= 30;
        }

        Color borderColor = Colors.green;
        if (vencido) {
          borderColor = Colors.red;
        } else if (prestesAVencer) {
          borderColor = Colors.orange;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          elevation: 2,
          child: ExpansionTile(
            leading: CircleAvatar(child: Icon(vencido || prestesAVencer ? Icons.warning_amber_rounded : Icons.medication_liquid), backgroundColor: borderColor.withOpacity(0.1), foregroundColor: borderColor),
            title: Text(data['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Quantidade: $quantidade | Nível Estimado: ${nivelEstoque ?? 'N/A'}"),
            trailing: Text(validade == null ? '' : DateFormat('MM/yy').format(validade.toDate()), style: TextStyle(color: vencido ? Colors.red : Colors.grey, fontWeight: vencido ? FontWeight.bold : FontWeight.normal)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    if (isAntibiotico)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(children: [Icon(Icons.info, color: Colors.blue.shade700, size: 16), const SizedBox(width: 8), const Expanded(child: Text("Não reutilize antibióticos sem recomendação médica.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)))]),
                      ),
                    if (dosagem != null && dosagem.isNotEmpty) _infoRow("Dosagem", dosagem),
                    if (observacao != null && observacao.isNotEmpty) _infoRow("Observação", observacao),
                    _infoRow("Validade", validade == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(validade.toDate()), highlight: vencido),
                    if (data['ean'] != null) _infoRow("Código de Barras", data['ean']),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (vencido || prestesAVencer)
                          ActionChip(
                            avatar: Icon(Icons.recycling, color: Colors.white),
                            label: const Text("Guia de Descarte"),
                            backgroundColor: vencido ? Colors.red.shade400 : Colors.orange.shade400,
                            onPressed: () => _showGuiaDescarte(context),
                          ),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _confirmarExclusao(doc.reference, data['nome'])),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(color: highlight ? Colors.red : Colors.black87, fontWeight: highlight ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
