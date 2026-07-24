import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/settings_service.dart';
import 'camera_list_screen.dart'; // Importa a CameraListScreen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dvrHostController = TextEditingController();
  final _dvrUserController = TextEditingController();
  final _dvrPassController = TextEditingController();
  final _esp32IpController = TextEditingController(); // Novo controller para o IP do ESP32

  final SettingsService _settingsService = SettingsService(); // Instância do serviço

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dvrHostController.text = prefs.getString('dvr_host') ?? AppConfig.dvrHost;
      _dvrUserController.text = prefs.getString('dvr_user') ?? AppConfig.dvrUsername;
      _dvrPassController.text = prefs.getString('dvr_pass') ?? AppConfig.dvrPassword;
      _esp32IpController.text = prefs.getString(SettingsService.esp32IpKey) ?? '192.168.1.100'; // Carrega o IP do ESP32
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dvr_host', _dvrHostController.text);
    await prefs.setString('dvr_user', _dvrUserController.text);
    await prefs.setString('dvr_pass', _dvrPassController.text);
    await _settingsService.saveEsp32Ip(_esp32IpController.text); // Salva o IP do ESP32

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configurações salvas com sucesso!'),
        backgroundColor: Colors.cyanAccent,
      ),
    );
    Navigator.pop(context, true); // Retorna true para atualizar o grid
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONFIGURAÇÕES GERAIS'), // Título mais abrangente
        backgroundColor: AppConfig.cardColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Seção de Configuração do DVR
            _buildSectionTitle('DVR AITEK CONFIG'),
            const SizedBox(height: 12),
            TextField(
              controller: _dvrHostController,
              decoration: const InputDecoration(
                labelText: 'Host / IP e Porta (ex: 192.168.15.55:554)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dvrUserController,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dvrPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32), // Espaço entre as seções

            // Seção de Configuração do ESP32
            _buildSectionTitle('ESP32 CONFIG'),
            const SizedBox(height: 12),
            TextField(
              controller: _esp32IpController,
              decoration: const InputDecoration(
                labelText: 'IP do ESP32 (ex: 192.168.1.100)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Botão Salvar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveSettings,
              child: const Text('SALVAR CONFIGURAÇÕES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            // Seção de Gerenciamento de Câmeras
            _buildSectionTitle('GERENCIAR CÂMERAS'),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.cardColor,
                foregroundColor: AppConfig.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraListScreen()),
                );
                // Optionally reload settings if CameraListScreen can affect them
                _loadSettings();
              },
              child: const Text('EDITAR LISTA DE CÂMERAS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: AppConfig.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}