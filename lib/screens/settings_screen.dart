import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
../config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dvrHostController = TextEditingController();
  final _dvrUserController = TextEditingController();
  final _dvrPassController = TextEditingController();

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
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dvr_host', _dvrHostController.text);
    await prefs.setString('dvr_user', _dvrUserController.text);
    await prefs.setString('dvr_pass', _dvrPassController.text);

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
        title: const Text('CONFIGURAÇÕES // STREAM'),
        backgroundColor: AppConfig.cardColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'DVR AITEK CONFIG',
              style: TextStyle(color: AppConfig.primaryColor, fontWeight: FontWeight.bold),
            ),
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
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveSettings,
              child: const Text('SALVAR CONFIGURAÇÕES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}