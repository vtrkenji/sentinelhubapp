import 'package:flutter/material.dart';
import '../services/esp32_service.dart';
import '../services/settings_service.dart';

class Esp32ConfigScreen extends StatelessWidget {
  const Esp32ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Esp32ConfigBody(),
    );
  }
}

class Esp32ConfigBody extends StatefulWidget {
  const Esp32ConfigBody({super.key});

  @override
  State<Esp32ConfigBody> createState() => _Esp32ConfigBodyState();
}

class _Esp32ConfigBodyState extends State<Esp32ConfigBody> {
  final _formKey = GlobalKey<FormState>();
  final _esp32Service = Esp32Service();
  final _settingsService = SettingsService();

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  bool _connected = false;
  String _deviceIp = '';

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final savedIp = await _settingsService.loadEsp32Ip();
    final savedSsid = await _settingsService.loadEsp32Ssid();
    final savedPassword = await _settingsService.loadEsp32Password();
    final savedTopic = await _settingsService.loadEsp32Topic();

    setState(() {
      _ipController.text = savedIp;
      _ssidController.text = savedSsid;
      _passwordController.text = savedPassword;
      _topicController.text = savedTopic;
    });

    await _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showMessage('Informe o IP do ESP32 para verificar o estado.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Verificando...';
    });

    final status = await _esp32Service.getStatusJson(ip);
    setState(() {
      _isLoading = false;
      _connected = status['connected'] == true;
      _deviceIp = status['ip']?.toString() ?? '';
      _statusMessage = status['message']?.toString() ??
          (_connected ? 'ESP32 disponível' : 'Dispositivo inacessível');
      _ssidController.text = status['ssid']?.toString() ?? _ssidController.text;
      _topicController.text = status['topic']?.toString() ?? _topicController.text;
    });
  }

  Future<void> _loadConfig() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showMessage('Informe o IP do ESP32 para carregar a configuração.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Carregando configuração...';
    });

    final config = await _esp32Service.getConfig(ip);
    setState(() {
      _isLoading = false;
      if (config.isNotEmpty) {
        _ssidController.text = config['ssid']?.toString() ?? '';
        _topicController.text = config['topic']?.toString() ?? '';
        _passwordController.text = '';
        _statusMessage = 'Configuração carregada com sucesso.';
      } else {
        _statusMessage = 'Não foi possível obter a configuração do ESP32.';
      }
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Corrija os campos obrigatórios antes de salvar.');
      return;
    }

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showMessage('Informe o IP do ESP32 antes de salvar.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Enviando credenciais para o ESP32...';
    });

    final success = await _esp32Service.updateConfig(
      ip,
      _ssidController.text.trim(),
      _passwordController.text,
      _topicController.text.trim(),
    );

    if (success) {
      await _settingsService.saveEsp32Ip(ip);
      await _settingsService.saveEsp32Ssid(_ssidController.text.trim());
      await _settingsService.saveEsp32Password(_passwordController.text);
      await _settingsService.saveEsp32Topic(_topicController.text.trim());
      _showMessage('Configurações enviadas. O ESP32 deve se reconectar em alguns segundos.');
      await _refreshStatus();
    } else {
      _showMessage('Falha ao enviar as configurações. Verifique a conexão e tente novamente.');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'IP do ESP32',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP do ESP32',
                hintText: 'Ex: 192.168.4.1 ou IP do modo estação',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    child: const Text('Salvar IP localmente'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _refreshStatus,
                    child: const Text('Verificar Status'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Status do ESP32',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Conectado: ${_connected ? 'Sim' : 'Não'}'),
                    const SizedBox(height: 4),
                    Text('IP respondente: ${_deviceIp.isEmpty ? '---' : _deviceIp}'),
                    const SizedBox(height: 4),
                    Text('Mensagem: $_statusMessage'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Credenciais do Wi-Fi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _ssidController,
                    decoration: const InputDecoration(labelText: 'SSID'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o SSID da rede Wi-Fi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha Wi-Fi'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe a senha da rede Wi-Fi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Tópico ntfy.sh',
                      hintText: 'Ex: meu_topico_secreto_sentinel',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o tópico ntfy.sh.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveConfig,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar configuração para ESP32'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loadConfig,
                    child: const Text('Carregar configuração atual do ESP32'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
