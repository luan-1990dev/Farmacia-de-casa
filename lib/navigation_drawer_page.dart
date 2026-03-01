import 'package:farmacia_de_casa/ajuda_page.dart';
import 'package:farmacia_de_casa/feedback_page.dart';
import 'package:flutter/material.dart';
import 'adicionar_medicamentos_page.dart';
import 'tela_estoque.dart';
import 'exames_consultas_page.dart';
import 'residentes_page.dart';
import 'contatos_emergencia_page.dart';
import 'dashboard_page.dart';
import 'doses_hoje_page.dart';
import 'compartilhamento_acesso_page.dart';

class NavigationDrawerPage extends StatelessWidget {
  const NavigationDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    const gradientDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEBF8FF),
      appBar: AppBar(
        title: const Text("Menu de Navegação"),
        centerTitle: true,
        flexibleSpace: Container(decoration: gradientDecoration),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: gradientDecoration,
                child: Center(
                  child: Text(
                    "Farmácia de Casa",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _buildDrawerItem(context, icon: Icons.medical_services, color: Colors.red, text: "Adicionar medicamento", page: const AdicionarMedicamentosPage()),
              _buildDrawerItem(context, icon: Icons.inventory_2_outlined, color: Colors.orange, text: "Controle de Estoque", page: const ControleEstoquePage()),
              _buildDrawerItem(context, icon: Icons.event_note, color: Colors.blueAccent, text: "Exames / Consulta", page: const ExamesConsultasPage()),
              _buildDrawerItem(context, icon: Icons.people_outline, color: Colors.purple, text: "Residentes", page: const ResidentesPage()),
              _buildDrawerItem(context, icon: Icons.share_location_outlined, color: Colors.cyan, text: "Cuidadores / Família", page: const CompartilhamentoAcessoPage()),
              _buildDrawerItem(context, icon: Icons.contact_phone_outlined, color: Colors.indigo, text: "Contatos de emergência", page: const ContatosEmergenciaPage()),
              
              //Dashboard e Doses movidos para o final da lista principal
              _buildDrawerItem(context, icon: Icons.check_circle_outline, color: Colors.green, text: "Doses de Hoje", page: const DosesHojePage()),
              _buildDrawerItem(context, icon: Icons.dashboard_outlined, color: Colors.teal, text: "Dashboard", page: const DashboardPage()),
              
              const Divider(),
              _buildDrawerItem(context, icon: Icons.help_outline, color: Colors.blueGrey, text: "Ajuda", page: const AjudaPage()),
              _buildDrawerItem(context, icon: Icons.feedback_outlined, color: Colors.brown, text: "Enviar Feedback", page: const FeedbackPage()),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Sair"),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Encerrar Sessão"),
                        content: const Text("Deseja realmente sair?"),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Cancelar"),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                            child: const Text("Sair"),
                            onPressed: () {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (Route<dynamic> route) => false,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEBF8FF),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 23.0),
            child: Image.asset(
              'assets/logo_moderno.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String text, Widget? page, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey.shade700),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        if (page != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
    );
  }
}
