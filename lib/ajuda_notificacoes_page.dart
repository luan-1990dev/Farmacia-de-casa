import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';

class AjudaNotificacoesPage extends StatefulWidget {
  const AjudaNotificacoesPage({super.key});

  @override
  State<AjudaNotificacoesPage> createState() => _AjudaNotificacoesPageState();
}

class _AjudaNotificacoesPageState extends State<AjudaNotificacoesPage> {
  String _deviceBrand = 'unknown';

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    setState(() {
      _deviceBrand = androidInfo.brand.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajuda com Notificações")
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildInstructions(),
      ),
    );
  }

  Widget _buildInstructions() {
    switch (_deviceBrand) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return _buildXiaomiInstructions();
      case 'samsung':
        return _buildSamsungInstructions();
      case 'motorola':
        return _buildMotorolaInstructions();
      default:
        return _buildGenericInstructions();
    }
  }

  Widget _buildInstructionCard({required String title, required List<String> steps, VoidCallback? onButtonPressed, String? buttonText}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20, thickness: 1),
            for (int i = 0; i < steps.length; i++) 
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(steps[i]),
              ),
            if (onButtonPressed != null && buttonText != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: Text(buttonText),
                    onPressed: onButtonPressed,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100)
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildXiaomiInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detectamos que seu celular é da Xiaomi/Poco/Redmi. Para garantir que os alarmes funcionem, siga os passos abaixo:", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        _buildInstructionCard(
          title: "Passo 1: Economia de Bateria", 
          steps: [
            "Na tela que abrir, encontre e selecione o 'Farmácia de Casa'.",
            "Toque em 'Economia de bateria'.",
            "Selecione a opção 'Nenhuma restrição'."
          ],
          buttonText: "Abrir Config. de Bateria",
          onButtonPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
        ),
        _buildInstructionCard(
          title: "Passo 2: Início Automático", 
          steps: [
            "Na tela de configurações do app que abrir, procure e toque em 'Permissões do app' ou uma opção similar.",
            "Procure por 'Início automático' ou 'Autostart'.",
            "Encontre o 'Farmácia de Casa' na lista e ative a chave."
          ],
          buttonText: "Abrir Permissões do App",
          onButtonPressed: () => AppSettings.openAppSettings(),
        ),
      ],
    );
  }

   Widget _buildSamsungInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detectamos que seu celular é da Samsung. Para garantir que os alarmes funcionem, siga os passos abaixo:", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        _buildInstructionCard(
          title: "Otimização de Bateria", 
          steps: [
            "Na tela que abrir, toque em 'Apps não otimizados' e mude para 'Todos'.",
            "Encontre o 'Farmácia de Casa' e desative a otimização.",
            "(Em versões mais novas) Vá em 'Apps nunca suspensos' e adicione o nosso app."
          ],
          buttonText: "Abrir Config. de Bateria",
          onButtonPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
        ),
      ],
    );
  }

  Widget _buildMotorolaInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detectamos que seu celular é da Motorola. Para garantir que os alarmes funcionem, siga os passos abaixo:", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        _buildInstructionCard(
          title: "Otimização de Bateria", 
          steps: [
            "Na tela que abrir, toque em 'Não otimizados' e mude para 'Todos os apps'.",
            "Encontre o 'Farmácia de Casa', toque nele e selecione 'Não otimizar'."
          ],
          buttonText: "Abrir Otimização de Bateria",
          onButtonPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
        ),
      ],
    );
  }

  Widget _buildGenericInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Para garantir que os alarmes funcionem, é importante desativar a otimização de bateria para o nosso aplicativo.", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        _buildInstructionCard(
          title: "Guia Geral", 
          steps: [
            "Vá nas 'Configurações' do seu celular.",
            "Procure pela seção 'Bateria' ou 'Apps'.",
            "Encontre as configurações de 'Otimização de Bateria'.",
            "Encontre o 'Farmácia de Casa' e marque-o como 'Não otimizado'."
          ],
          buttonText: "Abrir Config. de Bateria",
          onButtonPressed: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
        ),
      ],
    );
  }
}
