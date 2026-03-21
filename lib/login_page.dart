import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    _carregarEmailSalvo();
    usuarioController.addListener(() {
      if (usuarioController.text != _lastAttemptedEmail) {
        setState(() {
          _failedLoginAttempts = 0;
          _showForgotPassword = false;
        });
      }
    });
  }

  Future<void> _carregarEmailSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final emailSalvo = prefs.getString('user_email');
    if (emailSalvo != null) {
      setState(() {
        usuarioController.text = emailSalvo;
      });
    }
  }

  Future<void> _saveFcmToken(User user) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final userDocRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      await userDocRef.set({'fcmToken': fcmToken}, SetOptions(merge: true));
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('usuarios_registrados').doc(user.uid).set({
          'nome': user.displayName,
          'email': user.email?.toLowerCase(),
          'uid': user.uid,
        }, SetOptions(merge: true));

        await _saveFcmToken(user);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro Google: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final emailSalvo = prefs.getString('user_email');
    final senhaSalva = prefs.getString('user_password');

    if (emailSalvo == null || senhaSalva == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logue com senha primeiro para ativar a biometria."), backgroundColor: Colors.orangeAccent),
        );
      }
      return;
    }

    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Confirme sua biometria para acessar',
      );

      if (didAuthenticate && mounted) {
        setState(() => _isLoading = true);
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailSalvo, 
          password: senhaSalva
        );
        
        if (userCredential.user != null) {
          await _saveFcmToken(userCredential.user!);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      debugPrint("Erro biometria: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final currentEmail = usuarioController.text.trim().toLowerCase();
    final currentPassword = senhaController.text.trim();

    if (currentEmail.isEmpty || currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha os campos."), backgroundColor: Colors.orangeAccent));
      return;
    }
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: currentEmail, 
        password: currentPassword
      );
      
      if (mounted && userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', currentEmail);
        await prefs.setString('user_password', currentPassword);
        await _saveFcmToken(userCredential.user!);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      _failedLoginAttempts++;
      // Após 3 erros, sugere o Google como via de recuperação/acesso
      if (_failedLoginAttempts >= 3) setState(() => _showForgotPassword = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail ou senha incorretos."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/login_illustration.png', height: 180),
                  const SizedBox(height: 40),
                  
                  _buildInputField(
                    controller: usuarioController,
                    label: "Seu e-mail",
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInputField(
                    controller: senhaController,
                    label: "Sua senha",
                    icon: Icons.lock_outline,
                    obscure: !_isPasswordVisible,
                    suffix: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.blueGrey),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  if (_isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', height: 20),
                        label: const Text("ENTRAR COM GOOGLE", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        onPressed: _loginComGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Biometria Centralizada
                    _buildQuickAction(Icons.fingerprint, "Biometria", _authenticate),
                    
                    const SizedBox(height: 32),
                    
                    if (_showForgotPassword)
                      TextButton.icon(
                        onPressed: _loginComGoogle,
                        icon: const Icon(Icons.security, color: Colors.red, size: 18),
                        label: const Text('Esqueceu a senha? Redefina com o Google', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Não tem uma conta?"),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroUsuarioPage())),
                          child: const Text("Cadastre-se", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, bool obscure = false, TextInputType? type, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade50)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Column(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 40),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
