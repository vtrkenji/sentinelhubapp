import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/ntfy_native_service.dart';
import '../config/app_config.dart';
import 'update/update_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  late TextEditingController _ntfyTopicController;

  @override
  void initState() {
    super.initState();
    _ntfyTopicController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final topic = await _settingsService.loadNtfyTopic();
    setState(() {
      _ntfyTopicController.text = topic;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final topic = _ntfyTopicController.text.trim();
      await _settingsService.saveNtfyTopic(topic);
      
      // Restart Ntfy service to pick up the new topic
      NtfyNativeService.instance.stop();
      NtfyNativeService.instance.start();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preferências salvas com sucesso!'),
          backgroundColor: AppConfig.accentColor.withValues(alpha: 0.16 * 255),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ntfyTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferências do Aplicativo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Monitoramento (Ntfy)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ntfyTopicController,
                decoration: const InputDecoration(
                  labelText: 'Tópico Ntfy.sh (Local)',
                  hintText: 'ex: sentinel_vitor_01',
                  helperText: 'Canal de escuta para as notificações WebSocket'
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O tópico não pode estar vazio.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Salvar Preferências'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Sistema',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UpdateScreen()),
                  );
                },
                icon: const Icon(Icons.system_update_alt),
                label: const Text('Verificar Atualizações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
