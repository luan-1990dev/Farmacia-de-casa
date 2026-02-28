import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecuperarPorSmsPage extends StatefulWidget {
  const RecuperarPorSmsPage({super.key});

  @override
  State<RecuperarPorSmsPage> createState() => _RecuperarPorSmsPageState();
}

class _RecuperarPorSmsPageState extends State<RecuperarPorSmsPage> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  
  String? _verificationId;
  bool _codeSent = false;

  Future<void> _sendSmsCode() async {
    if (_phoneController.text.isEmpty) return;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+' + _phoneController.text.replaceAll(RegExp(r'[^0-9]'), ''), // Garante formato E.164
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Login automático em alguns casos (não usado para recuperação)
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falha na verificação: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _verifySmsCode() async {
    if (_verificationId == null || _smsController.text.isEmpty) return;

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _smsController.text,
    );

    try {
      // Apenas para validar o código. Não faz login.
      await FirebaseAuth.instance.signInWithCredential(credential);

      // TODO: Implementar a tela para redefinir a senha aqui.
      // Por enquanto, mostra sucesso e volta.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código validado com sucesso!"), backgroundColor: Colors.green));
      Navigator.of(context).pop(); 

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Código inválido: ${e.message}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recuperar por SMS")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeSent)
              ...[
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Número de Celular (com DDD)', hintText: 'Ex: 55119... '),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _sendSmsCode, child: const Text("Enviar Código")),
              ]
            else
              ...[
                Text("Enviamos um código para o número ${_phoneController.text}. Por favor, insira abaixo."),
                const SizedBox(height: 16),
                TextField(
                  controller: _smsController,
                  decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _verifySmsCode, child: const Text("Verificar e Redefinir"))
              ]
          ],
        ),
      ),
    );
  }
}
