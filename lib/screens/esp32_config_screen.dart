import 'package:flutter/material.dart';
import '../services/esp32_service.dart';
import '../services/settings_service.dart';
import '../config/app_config.dart';

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
  final TextEditingController _duckDomController = TextEditingController();
  final TextEditingController _duckTokController = TextEditingController();
  final TextEditingController _camp1Controller = TextEditingController();
  final TextEditingController _camp2Controller = TextEditingController();

  bool _isLoading = false;

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
    _duckDomController.dispose();
    _duckTokController.dispose();
    _camp1Controller.dispose();
    _camp2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final ip = await _settingsService.loadEsp32Ip();
    final ssid = await _settingsService.loadEsp32Ssid();
    final password = await _settingsService.loadEsp32Password();
    final topic = await _settingsService.loadEsp32Topic();
    final duckdom = await _settingsService.loadEsp32DuckDom();
    final ducktok = await _settingsService.loadEsp32DuckTok();
    final camp1 = await _settingsService.loadEsp32Camp1();
    final camp2 = await _settingsService.loadEsp32Camp2();

    setState(() {
      _ipController.text = ip.isEmpty ? '192.168.4.1' : ip;
      _ssidController.text = ssid.isEmpty ? 'vitorlandia2g' : ssid;
      _passwordController.text = password;
      _topicController.text = topic;
      _duckDomController.text = duckdom;
      _duckTokController.text = ducktok;
      _camp1Controller.text = camp1.isEmpty ? '130805' : camp1;
      _camp2Controller.text = camp2.isEmpty ? '4827093' : camp2;
    });

    // Tenta carregar automaticamente o status/config do ESP32 ao abrir a tela
    // caso haja um IP configurado.
    if (_ipController.text.trim().isNotEmpty) {
      // Aguarda um próximo frame para evitar chamadas durante a construção
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _testarConexao();
      });
    }
  }

  Future<void> _testarConexao() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showMessage('Informe o IP do ESP32 para testar a conexão.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final status = await _esp32Service.checkStatus(ip);

    setState(() {
      _isLoading = false;
    });

    if (status.isNotEmpty) {
      // Atualiza os campos com os dados que vieram do ESP32
      setState(() {
        if (status.containsKey('camp1')) _camp1Controller.text = status['camp1'].toString();
        if (status.containsKey('camp2')) _camp2Controller.text = status['camp2'].toString();
        if (status.containsKey('ntfy')) _topicController.text = status['ntfy'].toString();
        if (status.containsKey('duckdom')) _duckDomController.text = status['duckdom'].toString();
      });
      _showMessage('✅ Conectado! Configurações atuais carregadas.', isError: false);
    } else {
      _showMessage('❌ Falha na comunicação com o ESP32 ($ip).', isError: true);
    }
  }

  Future<void> _salvarConfig() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Corrija os campos obrigatórios antes de salvar.', isError: true);
      return;
    }

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showMessage('Informe o IP do ESP32 antes de salvar.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _esp32Service.salvarConfiguracoes(
      ip: ip,
      ssid: _ssidController.text.trim(),
      pass: _passwordController.text,
      ntfy: _topicController.text.trim(),
      duckdom: _duckDomController.text.trim(),
      ducktok: _duckTokController.text.trim(),
      camp1: _camp1Controller.text.trim(),
      camp2: _camp2Controller.text.trim(),
    );

    if (success) {
      // Salva localmente no app
      await _settingsService.saveEsp32Ip(ip);
      await _settingsService.saveEsp32Ssid(_ssidController.text.trim());
      await _settingsService.saveEsp32Password(_passwordController.text);
      await _settingsService.saveEsp32Topic(_topicController.text.trim());
      await _settingsService.saveEsp32DuckDom(_duckDomController.text.trim());
      await _settingsService.saveEsp32DuckTok(_duckTokController.text.trim());
      await _settingsService.saveEsp32Camp1(_camp1Controller.text.trim());
      await _settingsService.saveEsp32Camp2(_camp2Controller.text.trim());

      _showMessage('✅ Configurações salvas! O ESP32 será reiniciado.', isError: false);
    } else {
      _showMessage('❌ Falha ao salvar no ESP32. Verifique a conexão.', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppConfig.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌐 Conexão com o Dispositivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'Endereço IP do ESP32',
                        hintText: '192.168.4.1 (Modo AP) ou IP Local',
                        prefixIcon: Icon(Icons.router),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _testarConexao,
                        icon: const Icon(Icons.sync),
                        label: const Text('Testar Conexão / Ler Status'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppConfig.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📡 Rede Wi-Fi Alvo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ssidController,
                      decoration: const InputDecoration(labelText: 'SSID (Nome da Rede)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Senha da Rede', border: OutlineInputBorder()),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppConfig.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔔 Serviços & Notificações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(labelText: 'Tópico Ntfy.sh', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _duckDomController,
                      decoration: const InputDecoration(labelText: 'DuckDNS Domínio (Opcional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _duckTokController,
                      decoration: const InputDecoration(labelText: 'DuckDNS Token (Opcional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppConfig.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📻 Códigos RF 433MHz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _camp1Controller,
                            decoration: const InputDecoration(labelText: 'Código Campainha 1', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _camp2Controller,
                            decoration: const InputDecoration(labelText: 'Código Campainha 2', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _salvarConfig,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Salvar na Flash e Reiniciar ESP32', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.accentColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
