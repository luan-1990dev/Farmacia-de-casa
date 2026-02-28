import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResidentesPage extends StatefulWidget {
  const ResidentesPage({super.key});

  @override
  State<ResidentesPage> createState() => _ResidentesPageState();
}

class _ResidentesPageState extends State<ResidentesPage> {
  // Controladores para o formulário
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alergiaController = TextEditingController();
  final _doencaContagiosaController = TextEditingController();
  final _outraComorbidadeController = TextEditingController();

  // Variáveis de estado
  String? _tipoSanguineo;
  bool _temAlergia = false;
  bool _temDoencaContagiosa = false;
  String? _comorbidadeSelecionada;

  // Opções para os dropdowns
  final List<String> _tiposSanguineos = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _comorbidades = ['Pressão Alta', 'Diabetes Tipo 1', 'Diabetes Tipo 2', 'Diabetes Gestacional', 'Outros'];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _nomeController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alergiaController.dispose();
    _doencaContagiosaController.dispose();
    _outraComorbidadeController.dispose();
    super.dispose();
  }

  void _salvarResidente() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Preencha todos os campos obrigatórios (*)",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('residentes').add({
        'nome': _nomeController.text,
        'idade': int.tryParse(_idadeController.text),
        'peso': double.tryParse(_pesoController.text),
        'tipoSanguineo': _tipoSanguineo,
        'temAlergia': _temAlergia,
        'alergias': _temAlergia ? _alergiaController.text : null,
        'temDoencaContagiosa': _temDoencaContagiosa,
        'doencaContagiosa': _temDoencaContagiosa ? _doencaContagiosaController.text : null,
        'comorbidade': _comorbidadeSelecionada == 'Outros' ? _outraComorbidadeController.text : _comorbidadeSelecionada,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if(mounted) {
        Navigator.of(context).pop(); // Fecha a tela do formulário
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Residente salvo com sucesso!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    }
  }

  void _abrirFormularioResidente() {
    // Limpa os campos antes de abrir
    _formKey.currentState?.reset();
    _nomeController.clear();
    _idadeController.clear();
    _pesoController.clear();
    _alergiaController.clear();
    _doencaContagiosaController.clear();
    _outraComorbidadeController.clear();
    setState(() {
      _tipoSanguineo = null;
      _temAlergia = false;
      _temDoencaContagiosa = false;
      _comorbidadeSelecionada = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Novo Residente", style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const Divider(),
                    TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: "Nome Completo *"), validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    TextFormField(controller: _idadeController, decoration: const InputDecoration(labelText: "Idade *"), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? "Campo obrigatório" : null),
                    TextFormField(controller: _pesoController, decoration: const InputDecoration(labelText: "Peso (kg)"), keyboardType: TextInputType.number),
                    DropdownButtonFormField<String>(initialValue: _tipoSanguineo, items: _tiposSanguineos.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setModalState(() => _tipoSanguineo = v), decoration: const InputDecoration(labelText: "Tipo Sanguíneo")),
                    
                    SwitchListTile(title: const Text("Possui Alergia?"), value: _temAlergia, onChanged: (v) => setModalState(() => _temAlergia = v)),
                    if (_temAlergia) TextFormField(controller: _alergiaController, decoration: const InputDecoration(labelText: "Descreva a alergia")),

                    SwitchListTile(title: const Text("Doença Contagiosa?"), value: _temDoencaContagiosa, onChanged: (v) => setModalState(() => _temDoencaContagiosa = v)),
                    if (_temDoencaContagiosa) TextFormField(controller: _doencaContagiosaController, decoration: const InputDecoration(labelText: "Qual doença?")),

                    DropdownButtonFormField<String>(initialValue: _comorbidadeSelecionada, items: _comorbidades.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setModalState(() => _comorbidadeSelecionada = v), decoration: const InputDecoration(labelText: "Comorbidade Prioritária")),
                    if (_comorbidadeSelecionada == 'Outros') TextFormField(controller: _outraComorbidadeController, decoration: const InputDecoration(labelText: "Qual comorbidade?")),

                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _salvarResidente, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("Salvar Residente")),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showResumoResidente(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['nome'] ?? 'Detalhes do Residente'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow("Idade", data['idade']?.toString() ?? 'N/A'),
              _infoRow("Peso", "${data['peso']?.toString() ?? 'N/A'} kg"),
              _infoRow("Tipo Sanguíneo", data['tipoSanguineo'] ?? 'N/A'),
              const Divider(height: 20),
              _infoRow("Alergias", data['temAlergia'] == true ? (data['alergias'] ?? 'Sim') : 'Não', isAlert: data['temAlergia'] == true),
              _infoRow("Comorbidade", data['comorbidade'] ?? 'Nenhuma', isAlert: data['comorbidade'] != null),
              _infoRow("Doença Contagiosa", data['temDoencaContagiosa'] == true ? (data['doencaContagiosa'] ?? 'Sim') : 'Não', isAlert: data['temDoencaContagiosa'] == true),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))],
      ),
    );
  }

  void _confirmarExclusao(DocumentReference docRef, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text("Deseja realmente excluir o residente $nome? Esta ação é permanente."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              docRef.delete();
              Navigator.of(context).pop();
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Residentes"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('residentes').orderBy('nome').snapshots() : null,
        builder: (context, snapshot) {
          if (_currentUser == null) {
            return const Center(child: Text("Faça login para ver os residentes."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum residente cadastrado."));
          }

          return ListView(children: snapshot.data!.docs.map((doc) => _buildResidenteCard(doc)).toList());
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioResidente,
        icon: const Icon(Icons.add),
        label: const Text("Novo Residente"),
      ),
    );
  }

  Widget _buildResidenteCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final temAlergia = data['temAlergia'] == true;
    final comorbidade = data['comorbidade'] != null && data['comorbidade'].isNotEmpty;
    final temDoencaContagiosa = data['temDoencaContagiosa'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(data['nome'][0])), 
        title: Row(
          children: [
            Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
            if (temAlergia) const Tooltip(message: 'Possui Alergia', child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18)),
            if (comorbidade) const Tooltip(message: 'Comorbidade Prioritária', child: Icon(Icons.favorite, color: Colors.red, size: 18)),
            if (temDoencaContagiosa) const Tooltip(message: 'Doença Contagiosa', child: Icon(Icons.masks, color: Colors.purple, size: 18)),
          ],
        ),
        subtitle: Text("Idade: ${data['idade']} - ${data['tipoSanguineo'] ?? ''}"),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmarExclusao(doc.reference, data['nome'])),
        onTap: () => _showResumoResidente(data),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: TextStyle(color: isAlert ? Colors.red : Colors.black, fontWeight: isAlert ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}