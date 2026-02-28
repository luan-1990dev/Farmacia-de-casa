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

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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
          .child('${user?.uid ?? 'anonimo'}_${DateTime.now().toIso8601String()}.jpg');

      await ref.putFile(_imagemSelecionada!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro no upload da imagem: $e");
      return null;
    }
  }

  Future<void> _enviarFeedback() async {
    if (_feedbackController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor, escreva seu feedback antes de enviar.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
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
        'texto': _feedbackController.text,
        'imageUrl': imageUrl,
        'data': FieldValue.serverTimestamp(),
        'userId': user?.uid,
        'userEmail': user?.email,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Obrigado pelo seu feedback!"), backgroundColor: Colors.green),
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
      appBar: AppBar(
        title: const Text("Enviar Feedback"),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Sua opinião é muito importante para nós! Deixe sua sugestão, crítica ou relate um problema."),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: "Digite seu feedback aqui...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text("Anexar Imagem do Erro"),
                    onPressed: _escolherImagem,
                  ),
                  const SizedBox(height: 12),
                  if (_imagemSelecionada != null)
                    Center(
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            _imagemSelecionada!,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _imagemSelecionada = null),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, padding: EdgeInsets.zero),
                          )
                        ],
                      ),
                    ),
                  const SizedBox(height: 80),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _enviarFeedback,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Enviar"),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
