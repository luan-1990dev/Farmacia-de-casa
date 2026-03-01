import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;
  File? _imagemSelecionada;
  String _categoriaSelecionada = 'Sugestão';
  int _rating = 3; // Humor padrão: Neutro

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Bug / Erro', 'icon': Icons.bug_report_outlined, 'color': Colors.red},
    {'nome': 'Sugestão', 'icon': Icons.lightbulb_outline, 'color': Colors.amber},
    {'nome': 'Elogio', 'icon': Icons.thumb_up_outlined, 'color': Colors.green},
  ];

  final List<String> _humores = ['😠', '😐', '😊', '😍', '🤩'];

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _imagemSelecionada = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImagem() async {
    if (_imagemSelecionada == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseStorage.instance
          .ref()
          .child('feedback_images')
          .child('${user?.uid ?? 'anonimo'}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(_imagemSelecionada!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro no upload da imagem: $e");
      return null;
    }
  }

  Future<void> _enviarFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Escreva uma mensagem antes de enviar.", textAlign: TextAlign.center),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final imageUrl = await _uploadImagem();

      await FirebaseFirestore.instance.collection('feedbacks').add({
        'categoria': _categoriaSelecionada,
        'rating': _rating,
        'texto': _feedbackController.text.trim(),
        'imageUrl': imageUrl,
        'data': FieldValue.serverTimestamp(),
        'userId': user?.uid,
        'userEmail': user?.email,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Obrigado! Seu feedback foi enviado."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Enviar Feedback"),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildFormCard(),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _enviarFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("ENVIAR FEEDBACK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(Icons.send_rounded, size: 50, color: Colors.blueAccent),
        const SizedBox(height: 12),
        const Text(
          "Como podemos melhorar?",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Sua opinião nos ajuda a construir um app cada vez melhor para você.",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("O que você achou do app?", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_humores.length, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _rating == index + 1 ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _rating == index + 1 ? Colors.blue : Colors.transparent),
                    ),
                    child: Text(_humores[index], style: const TextStyle(fontSize: 28)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            const Text("Categoria", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categorias.map((cat) {
                final isSelected = _categoriaSelecionada == cat['nome'];
                return ChoiceChip(
                  label: Text(cat['nome']),
                  avatar: Icon(cat['icon'], size: 16, color: isSelected ? Colors.white : cat['color']),
                  selected: isSelected,
                  selectedColor: cat['color'],
                  onSelected: (selected) {
                    if (selected) setState(() => _categoriaSelecionada = cat['nome']);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Conte-nos mais detalhes...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _imagemSelecionada == null
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text("ANEXAR PRINT DO ERRO"),
                      onPressed: _escolherImagem,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : Column(
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imagemSelecionada!, height: 120, width: 120, fit: BoxFit.cover),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => setState(() => _imagemSelecionada = null),
                            ),
                          ],
                        ),
                        const Text("Imagem anexada", style: TextStyle(fontSize: 12, color: Colors.green)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
