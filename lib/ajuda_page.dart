import 'package:farmacia_de_casa/informacoes_app_page.dart';
import 'package:flutter/material.dart';

class AjudaPage extends StatelessWidget {
  const AjudaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajuda e Informações"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Sobre o App"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InformacoesAppPage())),
          ),
          // Adicione mais itens de ajuda aqui
        ],
      ),
    );
  }
}
