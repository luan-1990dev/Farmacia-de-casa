import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class ContatosEmergenciaPage extends StatefulWidget {
  const ContatosEmergenciaPage({super.key});

  @override
  State<ContatosEmergenciaPage> createState() => _ContatosEmergenciaPageState();
}

class _ContatosEmergenciaPageState extends State<ContatosEmergenciaPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  String? _parentescoSelecionado;
  bool _temWhatsapp = false;

  final List<String> _parentescos = ['Pai', 'Mãe', 'Cônjuge', 'Filho(a)', 'Irmão(ã)', 'Amigo(a)', 'Médico(a)', 'Outro'];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length <= 11) {
      return '55$normalized';
    }
    return normalized;
  }

  Future<void> _buscarContatoNaAgenda(StateSetter setModalState) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final Contact? contato = await FlutterContacts.openExternalPick();
        if (contato != null) {
          String phone = contato.phones.isNotEmpty ? contato.phones.first.number : '';
          phone = phone.replaceAll(RegExp(r'^(\+55|55)'), '').replaceAll(RegExp(r'[^0-9]'), '');

          setModalState(() {
            _nomeController.text = contato.displayName;
            _celularController.text = phone;
            _emailController.text = contato.emails.isNotEmpty ? contato.emails.first.address : '';
          });
        }
      } else {
        _showPermissionDeniedSnackbar();
      }
    } catch (e) {
      debugPrint("Erro ao abrir agenda: $e");
    }
  }

  void _showPermissionDeniedSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de contatos negada.'), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  void _abrirFormularioContato() {
    _nomeController.clear();
    _celularController.clear();
    _emailController.clear();
    _parentescoSelecionado = null;
    _temWhatsapp = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Novo Contato de Emergência", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.contact_phone),
                    label: const Text("Importar da Agenda"),
                    onPressed: () => _buscarContatoNaAgenda(setModalState),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome Completo *', prefixIcon: Icon(Icons.person)), validator: (v) => v!.isEmpty ? "Obrigatório" : null),
                  TextFormField(
                    controller: _celularController, 
                    decoration: const InputDecoration(
                      labelText: 'Celular (DDD + Número) *', 
                      prefixIcon: Icon(Icons.phone),
                      prefixText: '+55 ',
                      hintText: "Ex: 11988887777"
                    ), 
                    keyboardType: TextInputType.phone, 
                    validator: (v) => v!.isEmpty ? "Obrigatório" : (v.length < 10 ? "Número incompleto" : null)
                  ),
                  TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail (Opcional)', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
                  DropdownButtonFormField<String>(
                    value: _parentescoSelecionado,
                    items: _parentescos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setModalState(() => _parentescoSelecionado = v),
                    decoration: const InputDecoration(labelText: "Parentesco / Relação *", prefixIcon: Icon(Icons.family_restroom)),
                    validator: (v) => v == null ? "Obrigatório" : null,
                  ),
                  SwitchListTile(
                    title: GestureDetector(
                      onTap: () => _redirecionarParaAppWhatsapp(),
                      child: const Text("Este número possui WhatsApp?", style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                    ),
                    value: _temWhatsapp, 
                    onChanged: (v) => setModalState(() => _temWhatsapp = v)
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _salvarContato,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                    child: const Text("Salvar Contato", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _salvarContato() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final numeroNormalizado = _normalizePhoneNumber(_celularController.text);
      await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('contatos_emergencia').add({
        'nome': _nomeController.text,
        'celular': numeroNormalizado,
        'email': _emailController.text,
        'parentesco': _parentescoSelecionado,
        'temWhatsapp': _temWhatsapp,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contato salvo com sucesso!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    }
  }

  Future<void> _fazerChamada(String numero) async {
    final Uri uri = Uri.parse("tel:+$numero");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarWhatsApp(String numero, String nome) async {
    final url = "https://wa.me/$numero";
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _redirecionarParaAppWhatsapp() async {
    final Uri uri = Uri.parse("whatsapp://");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final Uri webUri = Uri.parse("https://wa.me/");
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contatos de Emergência"),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "Contatos", icon: Icon(Icons.people)), Tab(text: "Histórico", icon: Icon(Icons.history))],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildContatosTab(), _buildHistoricoTab()]),
      floatingActionButton: _tabController.index == 0 
          ? FloatingActionButton.extended(
              onPressed: _abrirFormularioContato,
              label: const Text("Novo Contato"),
              icon: const Icon(Icons.person_add),
              backgroundColor: Colors.blue.shade700,
            )
          : null,
    );
  }

  Widget _buildContatosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('contatos_emergencia').orderBy('criadoEm', descending: true).snapshots() : null,
      builder: (context, snapshot) {
        if (_currentUser == null) return const Center(child: Text("Faça login."));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contact_emergency_outlined, size: 100, color: Colors.blue.withOpacity(0.2)),
                  const SizedBox(height: 24),
                  const Text("Sua segurança é importante!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text("Adicione contatos de confiança para serem notificados em caso de emergência ou esquecimento de medicamentos.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final nome = data['nome'] ?? '';
            final parentesco = data['parentesco'] ?? 'Contato';
            final celular = data['celular'] ?? '';

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(nome[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text("$parentesco • +$celular"),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => doc.reference.delete()),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _fazerChamada(celular),
                          icon: const Icon(Icons.phone),
                          label: const Text("Ligar"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600, // Verde para Ligação
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (data['temWhatsapp'] == true)
                          ElevatedButton.icon(
                            onPressed: () => _enviarWhatsApp(celular, nome),
                            icon: const Icon(Icons.message),
                            label: const Text("WhatsApp"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent, // Azul para WhatsApp (Distinto)
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoricoTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('historico_alertas').orderBy('dataHora', descending: true).snapshots() : null,
      builder: (context, snapshot) {
        if (_currentUser == null) return const Center(child: Text("Faça login."));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text("Nenhum alerta enviado ainda.", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['dataHora'] as Timestamp?;
            final dataStr = timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : 'Agora';
            final tipo = data['tipo'] ?? 'Alerta';
            
            Color corStatus = Colors.blue;
            IconData iconeStatus = Icons.message;
            if (tipo.contains("Emergência")) {
              corStatus = Colors.red;
              iconeStatus = Icons.warning_rounded;
            } else if (tipo.contains("Dose")) {
              corStatus = Colors.orange;
              iconeStatus = Icons.alarm_off;
            } else if (tipo.contains("cancelado") || tipo.contains("bem")) {
              corStatus = Colors.green;
              iconeStatus = Icons.check_circle_outline;
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: corStatus.withOpacity(0.3), width: 1),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: corStatus.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(iconeStatus, color: corStatus),
                ),
                title: Text(tipo, style: TextStyle(fontWeight: FontWeight.bold, color: corStatus)),
                subtitle: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Para: '),
                      TextSpan(text: data['destinatario'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: ' via ${data['meio'] ?? '-'}'),
                    ],
                  ),
                ),
                trailing: Text(dataStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}
