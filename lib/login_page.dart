import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'cadastro_usuario.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;
  bool _showForgotPassword = false;
  bool _isPasswordVisible = false;
  
  int _failedLoginAttempts = 0;
  String _lastAttemptedEmail = "";

  @override
  void initState() {
    super.initState();
    usuarioController.addListener(() {
      if (usuarioController.text != _lastAttemptedEmail) {
        setState(() {
          _failedLoginAttempts = 0;
          _showForgotPassword = false;
        });
      }
    });
  }

  @override
  void dispose() {
    usuarioController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> _saveFcmToken(User user) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final userDocRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      await userDocRef.set({'fcmToken': fcmToken}, SetOptions(merge: true));
    }
  }

  Future<void> _authenticate() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Faça login com senha primeiro para habilitar a biometria."), backgroundColor: Colors.orangeAccent),
          );
        }
        return;
      }
      final bool didAuthenticate = await auth.authenticate(localizedReason: 'Confirme sua identidade para acessar');
      if (didAuthenticate && context.mounted) {
        await _saveFcmToken(user);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on PlatformException {
      // Silencioso
    } catch (e) {
      debugPrint("Erro de autenticação: $e");
    }
  }

  Future<void> _login() async {
    final currentEmail = usuarioController.text.trim().toLowerCase();
    final currentPassword = senhaController.text.trim();

    if (currentEmail.isEmpty || currentPassword.isEmpty) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Preencha email e senha."), backgroundColor: Colors.orangeAccent));
      return;
    }
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: currentEmail, password: currentPassword);
      if (mounted && userCredential.user != null) {
        await _saveFcmToken(userCredential.user!);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erro ao fazer login.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        message = "Email ou senha incorretos.";
        
        if (_lastAttemptedEmail == currentEmail) {
          _failedLoginAttempts++;
        } else {
          _failedLoginAttempts = 1;
          _lastAttemptedEmail = currentEmail;
        }

        if (_failedLoginAttempts >= 3) {
          _showForgotPassword = true;
        }

      } else if (e.code == 'invalid-email') {
        message = "O email digitado não é válido.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.black)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showExitDialog() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(title: const Text('Sair do aplicativo'), content: const Text('Você tem certeza que quer sair?'), actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair'))]),
    );
    if (shouldPop == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE0F7FA), Color(0xFFFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/login_illustration.png', height: 200),
                    const SizedBox(height: 30),
                    TextField(
                      controller: usuarioController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration(label: "Email", icon: Icons.person_outline),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: senhaController, 
                      obscureText: !_isPasswordVisible, 
                      decoration: _buildInputDecoration(
                        label: "Senha", 
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        )
                      )
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      _buildLoginButton(context, text: "Entrar", color: const Color(0xFFF9A825), onPressed: _login),
                      const SizedBox(height: 15),
                      _buildLoginButton(context, text: "Acessar com biometria", icon: Icons.fingerprint, isOutlined: true, onPressed: _authenticate),
                      const SizedBox(height: 15),
                      _buildLoginButton(context, text: "Criar usuário", color: const Color(0xFF00695C), onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroUsuarioPage()));
                      }),
                    ],
                    SizedBox(
                      height: 50,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _showForgotPassword ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 400),
                          child: _showForgotPassword
                              ? TextButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => RecuperarSenhaPage(email: usuarioController.text)));
                                  },
                                  child: Text('Redefinir Senha', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey.shade600), 
      labelText: label, 
      filled: true, 
      fillColor: Colors.white, 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildLoginButton(BuildContext context, {required String text, required VoidCallback onPressed, Color? color, IconData? icon, bool isOutlined = false}) {
    return SizedBox(
      width: double.infinity,
      child: isOutlined
          ? OutlinedButton.icon(icon: Icon(icon, color: Colors.grey.shade700), label: Text(text, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)), onPressed: onPressed, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade400, width: 1.5)))
          : ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2), child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
    );
  }
}

class RecuperarSenhaPage extends StatefulWidget {
  final String? email;
  const RecuperarSenhaPage({super.key, this.email});

  @override
  State<RecuperarSenhaPage> createState() => _RecuperarSenhaPageState();
}

class _RecuperarSenhaPageState extends State<RecuperarSenhaPage> {
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email?.trim().toLowerCase());
  }

  Future<void> _enviarEmailRecuperacao() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, digite seu email."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email enviado! Verifique o Spam caso não encontre."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Ocorreu um erro.";
      if (e.code == 'user-not-found') {
        message = "Este e-mail não está cadastrado.";
      } else if (e.code == 'invalid-email') {
        message = "O e-mail digitado não é válido.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recuperar Senha"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                'Recupere seu acesso',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 16),
              Text(
                'Digite seu email cadastrado e enviaremos um link para você redefinir sua senha.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _enviarEmailRecuperacao,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Enviar Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
