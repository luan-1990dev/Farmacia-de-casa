import 'package:flutter/material.dart';

class DowerPage extends StatelessWidget {
  const DowerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dados = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text("Resumo do Medicamento")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Medicamento: ${dados["medicamento"]}"),
            Text("Antibiótico: ${dados["antibiotico"] ? "Sim" : "Não"}"),
            Text("Uso: ${dados["uso"]}"),
            Text("Uso contínuo: ${dados["usoContinuo"] ? "Sim" : "Não"}"),
            Text("Frequência: ${dados["frequencia"]}"),
            Text("Modo de uso: ${dados["modoUso"]}"),
            Text("Quantidade: ${dados["quantidade"]}"),
            Text("Horários: ${dados["horarios"].join(", ")}"),
            Text("Data inicial: ${dados["dataInicial"]}"),
            Text("Data final: ${dados["dataFinal"]}"),
            Text("Validade: ${dados["validade"]}"),
            Text("Informações adicionais: ${dados["info"]}"),
          ],
        ),
      ),
    );
  }
}
