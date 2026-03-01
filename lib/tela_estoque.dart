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
  
  bool _estaPesquisando = false;
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = "";

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _buscaController.addListener(() {
      setState(() {
        _termoBusca = _buscaController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
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
                    TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: "Nome do Medicamento*", prefixIcon: Icon(Icons.edit_note))),
                    TextFormField(controller: dosagemController, decoration: const InputDecoration(labelText: "Dosagem (mg/ml)*", prefixIcon: Icon(Icons.science_outlined))),
                    TextFormField(controller: quantidadeController, decoration: const InputDecoration(labelText: "Quantidade (unidade)*", prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    Text("Quantidade (Nível Estimado)", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
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
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: Text(dataValidade == null ? "Validade (Mês/Ano)*" : "Validade: ${DateFormat('dd/MM/yyyy').format(dataValidade!)}"),
                      onTap: () => _selectDate(context, dataValidade, (picked) => setDialogState(() => dataValidade = picked)),
                    ),
                    TextFormField(
                      controller: observacaoController,
                      decoration: const InputDecoration(labelText: "Observações", prefixIcon: Icon(Icons.info_outline)),
                      maxLength: 60,
                    ),
                    TextField(controller: eanController, decoration: const InputDecoration(labelText: "Código de Barras", prefixIcon: Icon(Icons.qr_code))),
                    SwitchListTile(title: const Text("Uso Contínuo"), value: usoContinuo, onChanged: (value) => setDialogState(() => usoContinuo = value)),
                    SwitchListTile(title: const Text("É Antibiótico?"), value: isAntibiotico, onChanged: (value) => setDialogState(() => isAntibiotico = value)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nomeController.text.isEmpty || dosagemController.text.isEmpty || dataValidade == null) {
                      setDialogState(() => validationError = "Preencha os campos obrigatórios");
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
                    if (mounted) Navigator.of(context).pop();
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

  Future<void> _scanAndAdd() async {
    final codigo = await Navigator.push<String>(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
    if (codigo != null && mounted) {
      _showAddMedicamentoDialog(ean: codigo);
    }
  }

  List<DocumentSnapshot> _ordenarLista(List<DocumentSnapshot> docs) {
    List<DocumentSnapshot> listaOrdenada = List.from(docs);
    
    if (_termoBusca.isNotEmpty) {
      listaOrdenada = listaOrdenada.where((doc) {
        final nome = (doc.data() as Map<String, dynamic>)['nome']?.toString().toLowerCase() ?? "";
        return nome.contains(_termoBusca);
      }).toList();
    }

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
    if (_currentUser == null) return const Scaffold(body: Center(child: Text("Faça login.")));

    return Scaffold(
      appBar: AppBar(
        title: _estaPesquisando 
          ? TextField(
              controller: _buscaController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Buscar medicamento...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              autofocus: true,
            )
          : const Text("Estoque de Medicamentos"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        bottom: TabBar(controller: _tabController, indicatorColor: Colors.white, tabs: const [Tab(text: "Todos"), Tab(text: "Vencendo")]),
        actions: [
          _buildHighlightedIcon(
            icon: _estaPesquisando ? Icons.close : Icons.search,
            iconColor: Colors.amber.shade800,
            onPressed: () {
              setState(() {
                _estaPesquisando = !_estaPesquisando;
                if (!_estaPesquisando) _buscaController.clear();
              });
            },
          ),
          PopupMenuButton<OrdemOrdenacao>(
            offset: const Offset(0, 50),
            onSelected: (result) => setState(() => _ordemAtual = result),
            itemBuilder: (context) => [
              const PopupMenuItem(value: OrdemOrdenacao.nome, child: Text('Nome')),
              const PopupMenuItem(value: OrdemOrdenacao.validade, child: Text('Validade')),
              const PopupMenuItem(value: OrdemOrdenacao.quantidade, child: Text('Quantidade')),
            ],
            child: _buildHighlightedIcon(
              icon: Icons.sort_by_alpha,
              iconColor: Colors.deepOrangeAccent,
              onPressed: null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('medicamentos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allDocs = snapshot.data?.docs ?? [];
          final listaOrdenada = _ordenarLista(allDocs);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListaMedicamentos(listaOrdenada),
              _buildListaMedicamentos(listaOrdenada.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final validade = (data['validade'] as Timestamp?)?.toDate();
                if (validade == null) return false;
                return validade.difference(DateTime.now()).inDays <= 30;
              }).toList()),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicamentoDialog,
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade800,
        tooltip: "Adicionar Novo Item",
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                label: const Text("Escanear Código de Barras", style: TextStyle(color: Colors.blue)),
                onPressed: _scanAndAdd,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedIcon({required IconData icon, required Color iconColor, required VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildListaMedicamentos(List<DocumentSnapshot> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(_termoBusca.isEmpty ? "Nenhum item cadastrado." : "Nenhum medicamento encontrado para '$_termoBusca'", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final doc = lista[index];
        final data = doc.data() as Map<String, dynamic>;
        final nome = data['nome'] ?? 'Sem Nome';
        final qtd = (data['quantidade'] as num?)?.toInt() ?? 0;
        final validade = (data['validade'] as Timestamp?)?.toDate();
        final vencido = validade != null && validade.isBefore(DateTime.now());
        final nivel = data['nivelEstoque'] as String?;

        Color statusColor = Colors.green;
        if (vencido) {
          statusColor = Colors.red;
        } else if (validade != null && validade.difference(DateTime.now()).inDays <= 30) {
          statusColor = Colors.orange;
        } else if (nivel == "- 20%") {
          statusColor = Colors.amber.shade800;
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
            ),
            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("Qtd: $qtd | Nível: ${nivel ?? 'N/A'}"),
            trailing: Text(validade == null ? '' : DateFormat('MM/yy').format(validade), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (vencido)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            const SizedBox(width: 8),
                            const Expanded(child: Text("Este medicamento está vencido!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            TextButton(onPressed: () => _showGuiaDescarte(context), child: const Text("COMO DESCARTAR?")),
                          ],
                        ),
                      ),
                    _detailRow("Dosagem", data['dosagem'] ?? 'N/A'),
                    _detailRow("Validade", validade == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(validade)),
                    if (data['observacao'] != null && data['observacao'].isNotEmpty) _detailRow("Obs", data['observacao']),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarExclusao(doc.reference, nome)),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
