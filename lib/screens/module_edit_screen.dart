import 'package:flutter/material.dart';
import 'package:sentinel_hub/config/app_config.dart';
import 'package:sentinel_hub/models/hardware_module.dart';
import 'package:sentinel_hub/services/esp32_discovery_service.dart';
import 'package:sentinel_hub/services/module_service.dart';
import 'package:sentinel_hub/services/esp32_service.dart';
import 'package:sentinel_hub/utils/fcm_utils.dart';
import 'package:sentinel_hub/services/fcm_subscription_service.dart';

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
  late TextEditingController _duckDomController;
  late TextEditingController _duckTokController;
  late TextEditingController _camp1Controller;
  late TextEditingController _camp2Controller;
  late TextEditingController _fcmTopicController;

  final _esp32Service = Esp32Service();
  final _esp32DiscoveryService = Esp32DiscoveryService();
  ModuleType _selectedModuleType = ModuleType.gatewayEsp32C6Rf;

  bool _isEsp32C6RfGateway() => _selectedModuleType == ModuleType.gatewayEsp32C6Rf;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _nameController = TextEditingController(text: module?.name ?? '');
    _ipController = TextEditingController(text: module?.ipAddress ?? '');
    _selectedModuleType = module?.type ?? ModuleType.gatewayEsp32C6Rf;

    final specificSettings = module?.specificSettings ?? {};
    _duckDomController = TextEditingController(text: specificSettings['duckdom'] ?? '');
    _duckTokController = TextEditingController(text: specificSettings['ducktok'] ?? '');
    _camp1Controller = TextEditingController(text: specificSettings['camp1'] ?? '');
    _camp2Controller = TextEditingController(text: specificSettings['camp2'] ?? '');
    _fcmTopicController = TextEditingController(text: specificSettings['fcmtopic'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _duckDomController.dispose();
    _duckTokController.dispose();
    _camp1Controller.dispose();
    _camp2Controller.dispose();
    _fcmTopicController.dispose();
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

  String? _validateFcmTopic(String? value) {
    final error = FcmUtils.validateTopic(value);
    return error;
  }

  Future<void> _discoverEsp32OnNetwork() async {
    try {
      final results = (await _esp32DiscoveryService.discoverDevices(
        timeout: const Duration(seconds: 3),
      ))
          .where((device) => device.moduleType == 'esp32c6-rf')
          .toList();
      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum ESP32 encontrado na mesma rede Wi‑Fi/LAN.')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ESP32s encontrados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...results.map((device) {
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text('${device.ip}:${device.httpPort}'),
                      trailing: const Icon(Icons.wifi_tethering),
                      onTap: () {
                        setState(() {
                          _ipController.text = device.ip;
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ESP32 selecionado: ${device.ip}')),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
    } catch (e, stackTrace) {
      debugPrint('[ModuleEditScreen] Erro na descoberta UDP do ESP32: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível procurar ESP32 na rede. Verifique a Wi‑Fi/LAN.')),
        );
      }
    }
  }

  Future<void> _loadFromDevice() async {
    if (!_isEsp32C6RfGateway()) {
      return;
    }

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o IP do módulo para carregar.')));
      return;
    }

    final status = await _esp32Service.checkStatus(ip);
    if (status.isNotEmpty) {
      setState(() {
        if (status.containsKey('duckdom')) _duckDomController.text = status['duckdom'].toString();
        if (status.containsKey('camp1')) _camp1Controller.text = status['camp1'].toString();
        if (status.containsKey('camp2')) _camp2Controller.text = status['camp2'].toString();
        if (status.containsKey('fcmtopic')) _fcmTopicController.text = status['fcmtopic'].toString();
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
      final oldFcmTopic = widget.module?.specificSettings['fcmtopic'] as String? ?? '';
      final newFcmTopic = _fcmTopicController.text.trim();

      if (_isEsp32C6RfGateway()) {
        specificSettings['duckdom'] = _duckDomController.text.trim();
        specificSettings['ducktok'] = _duckTokController.text.trim();
        specificSettings['camp1'] = _camp1Controller.text.trim();
        specificSettings['camp2'] = _camp2Controller.text.trim();
        specificSettings['fcmtopic'] = newFcmTopic;
      } else {
        specificSettings['fcmtopic'] = newFcmTopic;
      }

      final moduleData = HardwareModule(
        id: widget.module?.id ?? '',
        name: _nameController.text,
        ipAddress: _ipController.text,
        type: _selectedModuleType,
        specificSettings: specificSettings,
      );

      if (_isEsp32C6RfGateway()) {
        final ip = _ipController.text.trim();
        final posted = await _esp32Service.salvarConfiguracoes(
          ip: ip,
          duckdom: _duckDomController.text.trim(),
          ducktok: _duckTokController.text.trim(),
          camp1: _camp1Controller.text.trim(),
          camp2: _camp2Controller.text.trim(),
          fcmTopic: newFcmTopic,
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

      // Handle FCM subscription/unsubscription
      if (oldFcmTopic != newFcmTopic) {
        // Unsubscribe from old topic if it's not used by other modules
        if (oldFcmTopic.isNotEmpty) {
          await FcmSubscriptionService.unsubscribeFromTopicIfUnused(oldFcmTopic);
        }
        // Subscribe to new topic
        if (newFcmTopic.isNotEmpty) {
          try {
            await FcmSubscriptionService.subscribeToAllModuleTopics();
          } catch (e) {
            debugPrint('[ModuleEditScreen] Erro ao atualizar subscrição FCM: $e');
          }
        }
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
              if (_isEsp32C6RfGateway()) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _loadFromDevice,
                    icon: const Icon(Icons.sync),
                    label: const Text('Carregar do ESP32'),
                  ),
                ),
              ],
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
    final isEsp32C6Rf = _isEsp32C6RfGateway();

    if (!isEsp32C6Rf) {
      return [];
    }

    return [
      Text('Configurações do Gateway ESP32-C6 (RF)', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _discoverEsp32OnNetwork,
          icon: const Icon(Icons.search),
          label: const Text('Procurar ESP32 na rede'),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(controller: _duckDomController, decoration: const InputDecoration(labelText: 'DuckDNS Domínio')),
      const SizedBox(height: 12),
      TextFormField(controller: _duckTokController, decoration: const InputDecoration(labelText: 'DuckDNS Token'), obscureText: true),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: TextFormField(controller: _camp1Controller, decoration: const InputDecoration(labelText: 'Código Campainha 1'), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _camp2Controller, decoration: const InputDecoration(labelText: 'Código Campainha 2'), keyboardType: TextInputType.number)),
        ],
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 12),
      const Text('Configuração FCM (Firebase Cloud Messaging)', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('Celulares configurados com este mesmo tópico receberão os alertas deste módulo.', style: TextStyle(fontSize: 12, color: AppConfig.mutedTextColor)),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _fcmTopicController,
              decoration: const InputDecoration(labelText: 'Tópico FCM da Casa'),
              validator: _validateFcmTopic,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _fcmTopicController.text = FcmUtils.generateSecureTopic();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Gerar tópico seguro'),
          ),
        ],
      ),
    ];
  }
}