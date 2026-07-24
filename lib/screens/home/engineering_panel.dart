import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/esp32_service.dart';
import '../../services/ntfy_service.dart'; // Importa o NtfyService
import '../settings_screen.dart';

class EngineeringPanel extends StatefulWidget {
  const EngineeringPanel({super.key});

  @override
  State<EngineeringPanel> createState() => _EngineeringPanelState();
}

class _EngineeringPanelState extends State<EngineeringPanel> {
  final SettingsService _settingsService = SettingsService();
  final Esp32Service _esp32Service = Esp32Service();
  final NtfyService _ntfyService = NtfyService(); // Instancia o NtfyService
  final TextEditingController _esp32IpController = TextEditingController();
  final List<String> _logs = [];

  bool? _isEsp32Online; // null: loading, true: online, false: offline
  bool _isCheckingStatus = false;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _loadAndCheckSettings();
    _addMockLog("Painel de engenharia inicializado.");

    // Inicia a escuta de alertas do Ntfy
    _ntfyService.startListening();
    _ntfyService.alertStream.listen((alert) {
      _addMockLog('ALERTA NTFY: ${alert.message}');
    }, onError: (error) {
      _addMockLog('ERRO NTFY: $error');
    });
  }

  @override
  void dispose() {
    _ntfyService.dispose(); // Finaliza o serviço
    _esp32IpController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCheckSettings() async {
    _esp32IpController.text = await _settingsService.loadEsp32Ip();
    _checkEsp32Status();
  }

  Future<void> _checkEsp32Status() async {
    if (_isCheckingStatus) return;
    setState(() {
      _isCheckingStatus = true;
      _isEsp32Online = null; // Set to loading state
    });

    _addMockLog("Pinging ESP32 em http://${_esp32IpController.text}/status...");
    final isOnline = await _esp32Service.checkStatus(_esp32IpController.text);
    if (!mounted) return;

    setState(() {
      _isEsp32Online = isOnline;
      _isCheckingStatus = false;
    });
    _addMockLog(isOnline ? "ESP32 está Online." : "ESP32 está Offline ou não respondeu.");
  }

  void _saveEsp32Ip() {
    _settingsService.saveEsp32Ip(_esp32IpController.text);
    _addMockLog("IP do ESP32 salvo: ${_esp32IpController.text}");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('IP do ESP32 salvo com sucesso!')),
    );
    _checkEsp32Status(); // Re-check status after saving a new IP
  }
  
  Future<void> _triggerRelay() async {
    setState(() => _isTriggering = true);
    _addMockLog("Acionando relé no ESP32 em http://${_esp32IpController.text}/trigger...");
    final result = await _esp32Service.triggerRelay(_esp32IpController.text);
    if (!mounted) return;

    _addMockLog("Resultado do acionamento: $result");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
    setState(() => _isTriggering = false);
  }

  void _addMockLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      _logs.insert(0, '[$timestamp] $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('PAINEL DE ENGENHARIA', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // Card de Configuração RTSP
        Card(
          color: cardColor,
          child: ListTile(
            leading: const Icon(Icons.router),
            title: const Text('Configuração de RTSP'),
            subtitle: const Text('URLs das câmeras e DVRs'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              _addMockLog("Retornou da tela de configurações.");
              _loadAndCheckSettings(); // Recarrega para refletir possíveis mudanças
            },
          ),
        ),
        const SizedBox(height: 12),
        
        // Card de IP do ESP32
        Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.developer_board),
                  title: const Text('Endereço IP do ESP32'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusIndicator(),
                      const SizedBox(width: 8),
                      Text(
                        _isEsp32Online == null ? 'Verificando...' : (_isEsp32Online! ? 'Online' : 'Offline'),
                        style: TextStyle(color: _isEsp32Online == null ? Colors.grey : (_isEsp32Online! ? Colors.green : Colors.red)),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _esp32IpController,
                  decoration: const InputDecoration(
                    hintText: 'ex: 192.168.1.100',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _checkEsp32Status,
                      child: _isCheckingStatus ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Verificar Status'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveEsp32Ip,
                      child: const Text('Salvar IP'),
                    ),
                  ],
                ),
                 const SizedBox(height: 8),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isTriggering ? null : _triggerRelay,
                    icon: _isTriggering ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Icon(Icons.flash_on),
                    label: const Text('Testar Disparo/Relé'),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Card de Logs
        Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.article),
                  title: Text('Logs de Eventos'),
                ),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                  ),
                  child: ListView.builder(
                    reverse: true, // Mostra os logs mais recentes no topo
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Text(_logs[index], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      );
                    },
                  ),
                ),
                 const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _addMockLog("Botão de teste de log pressionado."),
                    child: const Text('Gerar Log de Teste'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    if (_isEsp32Online == null) {
      return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _isEsp32Online! ? Colors.green : Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
