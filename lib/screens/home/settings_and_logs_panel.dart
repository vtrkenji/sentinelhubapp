import 'package:flutter/material.dart';
import '../../models/camera.dart';
import '../../services/camera_service.dart';
import '../../services/settings_service.dart';
import '../../services/esp32_service.dart';
import 'package:url_launcher/url_launcher.dart';


class SettingsAndLogsPanel extends StatefulWidget {
  final Camera? selectedCamera;
  final ValueChanged<Camera> onCameraSettingsChanged;

  const SettingsAndLogsPanel({
    super.key,
    required this.selectedCamera,
    required this.onCameraSettingsChanged,
  });

  @override
  State<SettingsAndLogsPanel> createState() => _SettingsAndLogsPanelState();
}

class _SettingsAndLogsPanelState extends State<SettingsAndLogsPanel> {
  final _cameraService = CameraService();
  final _settingsService = SettingsService();
  final _esp32Service = Esp32Service();

  late TextEditingController _nameController;
  late TextEditingController _rtspMainController;
  late TextEditingController _rtspSubController;
  late TextEditingController _esp32IpController;
  
  String? _selectedSnapshotFormat;
  final List<String> _logs = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _rtspMainController = TextEditingController();
    _rtspSubController = TextEditingController();
    _esp32IpController = TextEditingController();

    _updateControllersWithCameraData(widget.selectedCamera);
    _loadInitialSettings();
  }

  @override
  void didUpdateWidget(covariant SettingsAndLogsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCamera?.id != oldWidget.selectedCamera?.id) {
      _updateControllersWithCameraData(widget.selectedCamera);
    }
  }

  void _updateControllersWithCameraData(Camera? camera) {
    if (camera != null) {
      _nameController.text = camera.name;
      _rtspMainController.text = camera.rtspUrl;
      _rtspSubController.text = camera.rtspUrlSecondary ?? '';
      _selectedSnapshotFormat = camera.snapshotFormat ?? 'jpg';
    }
  }

  Future<void> _loadInitialSettings() async {
    _esp32IpController.text = await _settingsService.loadEsp32Ip();
    _addLog("Painel inicializado. Câmera selecionada: ${widget.selectedCamera?.name ?? 'Nenhuma'}");
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      _logs.insert(0, '[$timestamp] $message');
    });
  }

  Future<void> _saveAllSettings() async {
    if (widget.selectedCamera == null) return;
    setState(() => _isSaving = true);
    _addLog("Salvando todas as configurações...");

    try {
      // 1. Salvar configurações do ESP32
      await _settingsService.saveEsp32Ip(_esp32IpController.text);
      _addLog("IP do ESP32 salvo: ${_esp32IpController.text}");

      // 2. Atualizar e salvar dados da câmera
      final updatedCamera = widget.selectedCamera!.copyWith(
        name: _nameController.text,
        rtspUrl: _rtspMainController.text,
        rtspUrlSecondary: _rtspSubController.text,
        snapshotFormat: _selectedSnapshotFormat,
      );

      await _cameraService.updateCamera(updatedCamera);
      widget.onCameraSettingsChanged(updatedCamera); // Notifica o pai sobre a mudança
      _addLog("Configurações da câmera '${updatedCamera.name}' salvas.");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas as configurações foram salvas!')),
      );

    } catch (e) {
      _addLog("ERRO ao salvar: $e");
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar configurações: $e')),
      );
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<void> _testTrigger() async {
    _addLog("Testando disparo/relé em ${_esp32IpController.text}...");
    final result = await _esp32Service.triggerRelay(_esp32IpController.text);
    _addLog("Resultado do teste: $result");
  }

  Future<void> _testUrls() async {
    _addLog("Testando URLs para ${_nameController.text}...");
    final rtspMain = _rtspMainController.text;
    final rtspSub = _rtspSubController.text;

    // A simple URL validation, doesn't actually connect.
    bool mainOk = Uri.tryParse(rtspMain)?.hasAbsolutePath ?? false;
    bool subOk = Uri.tryParse(rtspSub)?.hasAbsolutePath ?? true; // OK if empty

    _addLog("URL Principal: ${mainOk ? 'Formato Válido' : 'Formato Inválido'}");
    _addLog("URL Secundária: ${subOk ? 'Formato Válido' : 'Formato Inválido'}");

     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mainOk && subOk ? 'Formatos de URL parecem válidos.' : 'Formato de URL inválido detectado.')),
      );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _rtspMainController.dispose();
    _rtspSubController.dispose();
    _esp32IpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCamera == null) {
      return const Center(child: Text('Nenhuma câmera selecionada'));
    }
    
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Seção de Configurações da Câmera ---
            Text(
              'CONFIG. CÂMERA SELECIONADA:',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
            Text(
              widget.selectedCamera!.name.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            
            _buildSectionHeader('CONFIGURAÇÕES INDIVIDUAIS'),
            _buildTextField(_nameController, 'Nome da Câmera'),
            _buildTextField(_rtspMainController, 'URL RTSP Principal'),
            _buildTextField(_rtspSubController, 'URL RTSP Secundária (Baixa)'),
            _buildSnapshotDropdown(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(onPressed: _testUrls, child: const Text('Testar URLs')),
            ),
            const Divider(height: 32),

            // --- Seção de Dispositivos e Engenharia ---
            _buildSectionHeader('DISPOSITIVOS & ENGENHARIA'),
            ElevatedButton(
                onPressed: () {
                    _addLog("Funcionalidade 'Configuração de RTSP' (lista global) a ser implementada.");
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.list_alt), SizedBox(width: 8), Text('Configuração de RTSP')])),
            const SizedBox(height: 16),
            _buildTextField(_esp32IpController, 'Endereço IP do ESP32'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(onPressed: _testTrigger, child: const Text('Testar Disparo/Relé')),
            ),
            const Divider(height: 32),

            // --- Seção de Logs ---
            _buildSectionHeader('LOGS DE EVENTOS'),
            _buildLogDisplay(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _addLog("Log de teste gerado manualmente."), child: const Text('Gerar Log de Teste')),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveAllSettings,
          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.save),
          label: Text(_isSaving ? 'SALVANDO...' : 'Salvar Todas as Configurações'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
  
  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSnapshotDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: _selectedSnapshotFormat,
        items: ['jpg', 'png', 'bmp'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value.toUpperCase()),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() => _selectedSnapshotFormat = newValue);
        },
        decoration: const InputDecoration(
          labelText: 'Formato de Snapshot',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildLogDisplay() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(_logs[index], style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          );
        },
      ),
    );
  }
}
