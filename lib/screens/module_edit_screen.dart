import 'package:flutter/material.dart';
import 'package:sentinel_hub/config/app_config.dart';
import 'package:sentinel_hub/models/hardware_module.dart';
import 'package:sentinel_hub/services/module_service.dart';
import 'package:sentinel_hub/services/esp32_service.dart';

class ModuleEditScreen extends StatefulWidget {
  final HardwareModule? module;

  const ModuleEditScreen({super.key, this.module});

  @override
  State<ModuleEditScreen> createState() => _ModuleEditScreenState();
}

class _ModuleEditScreenState extends State<ModuleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _moduleService = ModuleService();

  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _rfCodeController;
  late TextEditingController _rfProtocolController;
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  late TextEditingController _ntfyController;
  late TextEditingController _duckDomController;
  late TextEditingController _duckTokController;
  late TextEditingController _camp1Controller;
  late TextEditingController _camp2Controller;

  final _esp32Service = Esp32Service();
  ModuleType _selectedModuleType = ModuleType.genericEsp32;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _nameController = TextEditingController(text: module?.name ?? '');
    _ipController = TextEditingController(text: module?.ipAddress ?? '');
    _selectedModuleType = module?.type ?? ModuleType.genericEsp32;

    final specificSettings = module?.specificSettings ?? {};
    _rfCodeController = TextEditingController(text: specificSettings['rfCode'] ?? '');
    _rfProtocolController = TextEditingController(text: specificSettings['rfProtocol'] ?? '6');
    _ssidController = TextEditingController(text: specificSettings['ssid'] ?? '');
    _passwordController = TextEditingController(text: specificSettings['pass'] ?? '');
    _ntfyController = TextEditingController(text: specificSettings['ntfy'] ?? '');
    _duckDomController = TextEditingController(text: specificSettings['duckdom'] ?? '');
    _duckTokController = TextEditingController(text: specificSettings['ducktok'] ?? '');
    _camp1Controller = TextEditingController(text: specificSettings['camp1'] ?? '');
    _camp2Controller = TextEditingController(text: specificSettings['camp2'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _rfCodeController.dispose();
    _rfProtocolController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    _ntfyController.dispose();
    _duckDomController.dispose();
    _duckTokController.dispose();
    _camp1Controller.dispose();
    _camp2Controller.dispose();
    super.dispose();
  }

  String? _validateIpAddress(String? value) {
    if (value == null || value.isEmpty) return 'O endereço IP não pode ser vazio.';
    final ipRegex = RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    if (!ipRegex.hasMatch(value)) return 'Formato de endereço IP inválido.';
    return null;
  }

  String? _validateNotEmpty(String? value) {
    if (value == null || value.isEmpty) return 'Este campo não pode ser vazio.';
    return null;
  }

  Future<void> _loadFromDevice() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o IP do módulo para carregar.')));
      return;
    }

    final status = await _esp32Service.checkStatus(ip);
    if (status.isNotEmpty) {
      setState(() {
        if (status.containsKey('ssid')) _ssidController.text = status['ssid'].toString();
        if (status.containsKey('pass')) _passwordController.text = status['pass'].toString();
        if (status.containsKey('ntfy')) _ntfyController.text = status['ntfy'].toString();
        if (status.containsKey('duckdom')) _duckDomController.text = status['duckdom'].toString();
        if (status.containsKey('ducktok')) _duckTokController.text = status['ducktok'].toString();
        if (status.containsKey('camp1')) _camp1Controller.text = status['camp1'].toString();
        if (status.containsKey('camp2')) _camp2Controller.text = status['camp2'].toString();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações carregadas do ESP32.'), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao comunicar com o dispositivo em $ip'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final specificSettings = <String, dynamic>{};
      
      if (_selectedModuleType == ModuleType.wt32Eth01 || 
          _selectedModuleType == ModuleType.rfGateway || 
          _selectedModuleType == ModuleType.genericEsp32 || 
          _selectedModuleType == ModuleType.gatewayEsp32) {
        specificSettings['rfCode'] = _rfCodeController.text;
        specificSettings['rfProtocol'] = _rfProtocolController.text;
        specificSettings['ssid'] = _ssidController.text;
        specificSettings['pass'] = _passwordController.text;
        specificSettings['ntfy'] = _ntfyController.text;
        specificSettings['duckdom'] = _duckDomController.text;
        specificSettings['ducktok'] = _duckTokController.text;
        specificSettings['camp1'] = _camp1Controller.text;
        specificSettings['camp2'] = _camp2Controller.text;
      }

      final moduleData = HardwareModule(
        id: widget.module?.id ?? '', 
        name: _nameController.text,
        ipAddress: _ipController.text,
        type: _selectedModuleType,
        specificSettings: specificSettings,
      );

      if (_selectedModuleType == ModuleType.wt32Eth01 || 
          _selectedModuleType == ModuleType.rfGateway || 
          _selectedModuleType == ModuleType.genericEsp32 || 
          _selectedModuleType == ModuleType.gatewayEsp32) {
        final ip = _ipController.text.trim();
        final posted = await _esp32Service.salvarConfiguracoes(
          ip: ip,
          ssid: _ssidController.text.trim(),
          pass: _passwordController.text,
          ntfy: _ntfyController.text.trim(),
          duckdom: _duckDomController.text.trim(),
          ducktok: _duckTokController.text.trim(),
          camp1: _camp1Controller.text.trim(),
          camp2: _camp2Controller.text.trim(),
        );

        if (!posted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao salvar no ESP32. Verifique a conexão.'), backgroundColor: Colors.red));
          return;
        }
      }

      if (widget.module == null) {
        await _moduleService.addModule(moduleData);
      } else {
        await _moduleService.updateModule(moduleData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulo salvo com sucesso!'), backgroundColor: Colors.green));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar módulo: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module == null ? 'Adicionar Módulo' : 'Editar Módulo'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveModule, tooltip: 'Salvar Módulo'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Informações Gerais', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome/Identificador do Módulo'), validator: _validateNotEmpty),
              const SizedBox(height: 16),
              TextFormField(controller: _ipController, decoration: const InputDecoration(labelText: 'Endereço IP'), validator: _validateIpAddress, keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: _loadFromDevice, icon: const Icon(Icons.sync), label: const Text('Carregar do ESP32'))),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModuleType>(
                initialValue: _selectedModuleType,
                decoration: const InputDecoration(labelText: 'Tipo de Módulo'),
                items: ModuleType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.displayName))).toList(),
                onChanged: (type) {
                  if (type != null) setState(() => _selectedModuleType = type);
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              ..._buildSpecificSettingsFields(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpecificSettingsFields() {
    if (_selectedModuleType == ModuleType.wt32Eth01 || 
        _selectedModuleType == ModuleType.rfGateway || 
        _selectedModuleType == ModuleType.genericEsp32 || 
        _selectedModuleType == ModuleType.gatewayEsp32) {
      return [
        Text('Configurações Específicas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextFormField(controller: _rfCodeController, decoration: const InputDecoration(labelText: 'Código RF da Campainha'), keyboardType: TextInputType.number, validator: _validateNotEmpty),
        const SizedBox(height: 16),
        TextFormField(controller: _rfProtocolController, decoration: const InputDecoration(labelText: 'Protocolo RF'), keyboardType: TextInputType.number, validator: _validateNotEmpty),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Parâmetros Avançados ESP32', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextFormField(controller: _ssidController, decoration: const InputDecoration(labelText: 'SSID (Wi‑Fi)')),
        const SizedBox(height: 12),
        TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Senha Wi‑Fi'), obscureText: true),
        const SizedBox(height: 12),
        TextFormField(controller: _ntfyController, decoration: const InputDecoration(labelText: 'Tópico Ntfy.sh do ESP32')),
        const SizedBox(height: 12),
        TextFormField(controller: _duckDomController, decoration: const InputDecoration(labelText: 'DuckDNS Domínio')),
        const SizedBox(height: 12),
        TextFormField(controller: _duckTokController, decoration: const InputDecoration(labelText: 'DuckDNS Token')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _camp1Controller, decoration: const InputDecoration(labelText: 'Código Campainha 1'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _camp2Controller, decoration: const InputDecoration(labelText: 'Código Campainha 2'), keyboardType: TextInputType.number)),
          ],
        ),
      ];
    }
    return [];
  }
}