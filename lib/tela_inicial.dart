import 'package:flutter/material.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      appBar: AppBar(
        title: const Text("Painel Principal"),
        backgroundColor: Colors.blue.shade600,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),

      // ✅ MENU LATERAL (abre pelo lado direito)
      endDrawer: Drawer(
        child: Container(
          color: Colors.grey.shade100,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                ),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    "Menu",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              _menuItem(Icons.inventory, "Estoque"),
              _menuItem(Icons.favorite, "Como está sua saúde?"),
              _menuItem(Icons.history, "Histórico"),
              _menuItem(Icons.medical_services, "Vias de aplicação"),
              _menuItem(Icons.people, "Residentes"),
              _menuItem(Icons.contact_phone, "Contatos"),
              _menuItem(Icons.biotech, "Exames"),
              _menuItem(Icons.person_add, "Adicionar paciente"),
            ],
          ),
        ),
      ),

      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Text(
            "Bem-vindo ao sistema!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Função para criar cada item do menu
  Widget _menuItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Colors.blue.shade900,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // fecha o menu
        // Aqui você coloca a navegação para cada tela
      },
    );
  }
}
