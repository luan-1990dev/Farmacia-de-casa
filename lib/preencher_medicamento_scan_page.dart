import 'package:flutter/material.dart';

class PreencherMedicamentoScanPage extends StatefulWidget {
  final String barcode;

  const PreencherMedicamentoScanPage({super.key, required this.barcode});

  @override
  State<PreencherMedicamentoScanPage> createState() => _PreencherMedicamentoScanPageState();
}

class _PreencherMedicamentoScanPageState extends State<PreencherMedicamentoScanPage> {
  final _nomeController = TextEditingController();
  int? _anoSelecionado;
  int? _mesSelecionado;
  int? _diaSelecionado;

  // Listas para os dropdowns
  List<int> anos = [];
  List<int> meses = [];
  List<int> dias = [];

  @override
  void initState() {
    super.initState();
    // Gera as listas apenas uma vez
    anos = List<int>.generate(15, (i) => DateTime.now().year + i);
    meses = List<int>.generate(12, (i) => i + 1);
    dias = List<int>.generate(31, (i) => i + 1);
  }

  void _confirmar() {
    if (_nomeController.text.isNotEmpty && _anoSelecionado != null && _mesSelecionado != null && _diaSelecionado != null) {
      try {
        final dataValidade = DateTime(_anoSelecionado!, _mesSelecionado!, _diaSelecionado!);
        Navigator.of(context).pop({
          'nome': _nomeController.text,
          'validade': dataValidade,
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data de validade inválida.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.orangeAccent),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, preencha todos os campos.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Identificar Medicamento"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Código de Barras: ${widget.barcode}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: "Nome do Medicamento"),
              ),
              const SizedBox(height: 24),
              const Text("Data de Validade", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _diaSelecionado,
                      hint: const Text('Dia'),
                      items: dias.map((d) => DropdownMenuItem(value: d, child: Text(d.toString()))).toList(),
                      onChanged: (val) => setState(() => _diaSelecionado = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _mesSelecionado,
                      hint: const Text('Mês'),
                      items: meses.map((m) => DropdownMenuItem(value: m, child: Text(m.toString()))).toList(),
                      onChanged: (val) => setState(() => _mesSelecionado = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _anoSelecionado,
                      hint: const Text('Ano'),
                      items: anos.map((a) => DropdownMenuItem(value: a, child: Text(a.toString()))).toList(),
                      onChanged: (val) => setState(() => _anoSelecionado = val),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text("Confirmar e Voltar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
