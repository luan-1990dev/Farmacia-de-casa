import 'package:flutter/material.dart';

class InformacoesAppPage extends StatelessWidget {
  const InformacoesAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sobre as Funções do App"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: const [
          FeatureCard(
            icon: Icons.medical_services,
            color: Colors.red,
            title: "Adicionar Tratamento",
            description: "Use esta tela para agendar os horários, a frequência e a duração de um medicamento que você precisa tomar. É aqui que você cria os alarmes e lembretes.",
          ),
          FeatureCard(
            icon: Icons.inventory_2_outlined,
            color: Colors.orange,
            title: "Controle de Estoque",
            description: "Esta é a sua farmácia de casa. Adicione todos os medicamentos que você compra, controle a quantidade e a data de validade, independentemente de estarem em um tratamento ativo ou não.",
          ),
          FeatureCard(
            icon: Icons.event_note,
            color: Colors.blueAccent,
            title: "Exames / Consulta",
            description: "Agende e seja lembrado de seus compromissos médicos. Você pode cadastrar exames e consultas, definindo data, hora e local para não perder nenhum agendamento.",
          ),
          FeatureCard(
            icon: Icons.people_outline,
            color: Colors.purple,
            title: "Residentes",
            description: "Crie perfis para as pessoas que você cuida (filhos, pais, pacientes). Isso permite guardar informações de saúde importantes, como tipo sanguíneo e alergias, para cada um.",
          ),
           FeatureCard(
            icon: Icons.favorite_border,
            color: Colors.pink,
            title: "Sua Saúde",
            description: "Um local para registrar suas informações vitais, como tipo sanguíneo, alergias conhecidas e comorbidades. Essencial para consultas e emergências.",
          ),
          FeatureCard(
            icon: Icons.contact_phone_outlined,
            color: Colors.indigo,
            title: "Contatos de Emergência",
            description: "Adicione contatos de confiança da sua agenda. O app pode usar esses contatos para enviar alertas rápidos via WhatsApp em caso de necessidade.",
          ),
          FeatureCard(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            title: "Doses de Hoje",
            description: "Uma lista diária e interativa de todas as doses de medicamentos que você precisa tomar no dia atual. Marque as doses como 'tomadas' para acompanhar seu progresso.",
          ),
          FeatureCard(
            icon: Icons.dashboard_outlined,
            color: Colors.teal,
            title: "Dashboard",
            description: "Tenha uma visão geral e gráfica da sua saúde e tratamentos. Acompanhe a adesão aos seus tratamentos e veja como seu estoque de medicamentos está sendo utilizado.",
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              description,
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}
