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
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  bool _temWhatsapp = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    if (normalized.length > 9 && !normalized.startsWith('55')) {
      return '55$normalized';
    }
    return normalized;
  }

  Future<void> _buscarContatoNaAgenda() async {
    final status = await Permission.contacts.status;
    if (status.isDenied) {
      if (await Permission.contacts.request().isGranted) {
        _pickContact();
      } else {
        _showPermissionDeniedSnackbar();
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedSnackbar();
      openAppSettings();
    } else {
      _pickContact();
    }
  }

  Future<void> _pickContact() async {
    final Contact? contato = await FlutterContacts.openExternalPick();
    if (contato != null) {
      setState(() {
        _nomeController.text = contato.displayName;
        _celularController.text = contato.phones.isNotEmpty ? contato.phones.first.number : '';
        _emailController.text = contato.emails.isNotEmpty ? contato.emails.first.address : '';
      });
    }
  }

  void _showPermissionDeniedSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão de contatos negada. Ative nas configurações do app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  Future<void> _adicionarContato() async {
    if (_currentUser == null || _nomeController.text.isEmpty || _celularController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Nome e Celular são obrigatórios.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    try {
      final numeroNormalizado = _normalizePhoneNumber(_celularController.text);

      await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('contatos_emergencia').add({
        'nome': _nomeController.text,
        'celular': numeroNormalizado,
        'email': _emailController.text,
        'temWhatsapp': _temWhatsapp,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _nomeController.clear();
        _celularController.clear();
        _emailController.clear();
        setState(() => _temWhatsapp = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contato adicionado!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    }
  }

  Future<void> _enviarAlerta(String tipoAlerta, Map<String, dynamic> contato, String meio) async {
    if (_currentUser == null) return;

    final nomeContato = contato['nome'] as String;
    final celularContato = contato['celular'] as String? ?? '';
    final emailContato = contato['email'] as String? ?? '';
    
    String mensagem;
    switch (tipoAlerta) {
      case "Dose não tomada":
        mensagem = "Olá $nomeContato, este é um alerta automático. Esqueci de tomar uma dose do meu medicamento.";
        break;
      case "Alerta cancelado":
        mensagem = "Olá $nomeContato, está tudo bem. O alerta anterior foi um engano.";
        break;
      default:
        mensagem = "Olá $nomeContato, estou tendo uma emergência médica. Por favor, entre em contato.";
    }

    Uri? uri;

    if (meio == 'whatsapp') {
      if (celularContato.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Este contato não possui celular para WhatsApp.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
         return;
      }
      final numeroParaWhatsapp = _normalizePhoneNumber(celularContato);
      final url = "https://wa.me/$numeroParaWhatsapp?text=${Uri.encodeComponent(mensagem)}";
      uri = Uri.parse(url);
    } else if (meio == 'email') {
      if (emailContato.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Este contato não possui email.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      uri = Uri.parse("mailto:$emailContato?subject=${Uri.encodeComponent(tipoAlerta)}&body=${Uri.encodeComponent(mensagem)}");
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('historico_alertas').add({
        'tipo': tipoAlerta,
        'destinatario': nomeContato,
        'meio': meio,
        'dataHora': FieldValue.serverTimestamp(),
      });
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Não foi possível abrir o $meio. Verifique se o app está instalado.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: "Contatos", icon: Icon(Icons.contacts)), Tab(text: "Histórico", icon: Icon(Icons.history))],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildContatosTab(), _buildHistoricoTab()]),
    );
  }

  Widget _buildContatosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Adicionar Novo Contato", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.contact_phone_outlined), label: const Text("Buscar na Agenda"), onPressed: _buscarContatoNaAgenda, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
                  const SizedBox(height: 12),
                  TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person))),
                  TextField(controller: _celularController, decoration: const InputDecoration(labelText: 'Celular', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
                  SwitchListTile(title: const Text("Este número possui WhatsApp?"), value: _temWhatsapp, onChanged: (val) => setState(() => _temWhatsapp = val)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _adicionarContato, 
                      child: const Text('Salvar Contato'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Meus Contatos Salvos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('contatos_emergencia').orderBy('criadoEm', descending: true).snapshots() : null,
            builder: (context, snapshot) {
              if (_currentUser == null) return const Center(child: Text("Faça login para ver contatos."));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Nenhum contato cadastrado.")));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = data['nome'] ?? '';
                  final temWhatsapp = data['temWhatsapp'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?')),
                      title: Row(
                        children: [
                          Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if(temWhatsapp) const SizedBox(width: 8),
                          if(temWhatsapp) const Icon(Icons.message, color: Colors.green, size: 16),
                        ],
                      ),
                      subtitle: Text(data['celular'] ?? '-'),
                      children: [
                        Column(
                          children: [
                            ListTile(leading: const Icon(Icons.warning_amber_rounded, color: Colors.red), title: const Text("Alerta de Emergência"), onTap: () => _enviarAlerta("Emergência Médica", data, "whatsapp")),
                            ListTile(leading: const Icon(Icons.alarm_off, color: Colors.orange), title: const Text("Avisar Dose Perdida"), onTap: () => _enviarAlerta("Dose não tomada", data, "whatsapp")),
                            ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text("Cancelar Alerta (Estou bem)"), onTap: () => _enviarAlerta("Alerta cancelado", data, "whatsapp")),
                            const Divider(),
                            IconButton(icon: const Icon(Icons.delete_forever_outlined, color: Colors.grey), tooltip: "Remover Contato", onPressed: () => doc.reference.delete()),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricoTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(_currentUser!.uid).collection('historico_alertas').orderBy('dataHora', descending: true).snapshots() : null,
      builder: (context, snapshot) {
        if (_currentUser == null) return const Center(child: Text("Faça login."));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("Nenhum alerta enviado ainda."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['dataHora'] as Timestamp?;
            final dataStr = timestamp != null ? DateFormat('dd/MM HH:mm').format(timestamp.toDate()) : 'Agora';

            return Card(
              child: ListTile(
                leading: Icon(data['meio'] == 'whatsapp' ? Icons.message : Icons.email, color: data['meio'] == 'whatsapp' ? Colors.green : Colors.blueAccent),
                title: Text(data['tipo'] ?? 'Alerta'),
                subtitle: Text('Enviado para ${data['destinatario'] ?? '-'} via ${data['meio'] ?? '-'}'),
                trailing: Text(dataStr, style: const TextStyle(fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }
}
