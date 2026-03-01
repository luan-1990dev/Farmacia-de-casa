import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CompartilhamentoAcessoPage extends StatefulWidget {
  const CompartilhamentoAcessoPage({super.key});

  @override
  State<CompartilhamentoAcessoPage> createState() => _CompartilhamentoAcessoPageState();
}

class _CompartilhamentoAcessoPageState extends State<CompartilhamentoAcessoPage> {
  final _emailController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  User? get _currentUser => _auth.currentUser;

  Future<void> _convidarCuidador() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verificar se o e-mail convidado existe no sistema
      final userQuery = await _firestore.collection('usuarios_registrados').where('email', isEqualTo: email).get();

      if (userQuery.docs.isEmpty) {
        throw "Usuário não encontrado. Certifique-se que o cuidador já tem conta no app.";
      }

      final cuidadorData = userQuery.docs.first;
      final cuidadorUid = cuidadorData.id;

      if (cuidadorUid == _currentUser!.uid) {
        throw "Você não pode convidar a si mesmo.";
      }

      // 2. Criar o vínculo de compartilhamento
      await _firestore.collection('compartilhamentos').add({
        'pacienteId': _currentUser!.uid,
        'pacienteNome': _currentUser!.displayName ?? "Paciente",
        'pacienteEmail': _currentUser!.email,
        'cuidadorId': cuidadorUid,
        'cuidadorEmail': email,
        'status': 'ativo',
        'criadoEm': FieldValue.serverTimestamp(),
      });

      _emailController.clear();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acesso compartilhado com sucesso!"), backgroundColor: Colors.green));

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cuidadores / Família"),
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
            _buildMyInfoCard(),
            const SizedBox(height: 24),
            _buildInviteCard(),
            const SizedBox(height: 24),
            const Text("Pessoas que cuidam de mim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildCuidadorList(),
            const SizedBox(height: 24),
            const Text("Pessoas que eu cuido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildPacienteList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.qr_code_2, size: 50, color: Colors.blue),
            const SizedBox(height: 8),
            const Text("Seu E-mail de Compartilhamento", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(_currentUser?.email ?? "", style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
            const Text("Passe este e-mail para quem for cuidar de você.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Convidar Novo Cuidador", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "E-mail do cuidador",
                hintText: "exemplo@email.com",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _convidarCuidador,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1),
                label: const Text("DAR ACESSO AOS MEUS DADOS"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuidadorList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('compartilhamentos').where('pacienteId', isEqualTo: _currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("Ninguém tem acesso aos seus dados ainda.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(data['cuidadorEmail'] ?? "Cuidador"),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => docs[index].reference.delete(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPacienteList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('compartilhamentos').where('cuidadorId', isEqualTo: _currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("Você não está cuidando de ninguém no momento.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.health_and_safety, color: Colors.white)),
              title: Text(data['pacienteEmail'] ?? "Paciente"),
              subtitle: const Text("Você tem acesso aos dados deste usuário"),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            );
          },
        );
      },
    );
  }
}
