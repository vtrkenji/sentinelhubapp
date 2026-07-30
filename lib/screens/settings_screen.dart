import 'package:flutter/material.dart';
import '../main.dart';
import '../models/rf_device.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _ntfyEnabled = false;
  late TextEditingController _ntfyTopicUrlController;
  List<RFDevice> _rfDevices = [];

  @override
  void initState() {
    super.initState();
    _ntfyTopicUrlController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _ntfyEnabled = await settingsService.loadNtfyEnabled();
    _ntfyTopicUrlController = TextEditingController(text: await settingsService.loadNtfyTopicUrl());
    _rfDevices = await settingsService.loadRfDevices();
    setState(() {});
  }

  Future<void> _saveSettings() async {
    await settingsService.saveNtfyEnabled(_ntfyEnabled);
    await settingsService.saveNtfyTopicUrl(_ntfyTopicUrlController.text);
    await settingsService.saveRfDevices(_rfDevices);
    
    // Restart the ntfy stream service to apply changes
    await ntfyStreamService.restart();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas!')),
    );
  }

  void _addDevice() {
    _showDeviceDialog();
  }

  void _editDevice(RFDevice device) {
    _showDeviceDialog(device: device);
  }

  void _deleteDevice(RFDevice device) {
    setState(() {
      _rfDevices.remove(device);
    });
  }

  void _showDeviceDialog({RFDevice? device}) {
    final codeController = TextEditingController(text: device?.code.toString() ?? '');
    final nameController = TextEditingController(text: device?.name ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(device == null ? 'Adicionar Dispositivo' : 'Editar Dispositivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Código RF'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome do Dispositivo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final int? code = int.tryParse(codeController.text);
                final String name = nameController.text;
                if (code != null && name.isNotEmpty) {
                  setState(() {
                    if (device == null) {
                      _rfDevices.add(RFDevice(code: code, name: name));
                    } else {
                      device.code = code;
                      device.name = name;
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notificações (ntfy.sh)', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
              title: const Text('Habilitar Listener ntfy.sh'),
              value: _ntfyEnabled,
              onChanged: (bool value) {
                setState(() {
                  _ntfyEnabled = value;
                });
              },
            ),
            TextFormField(
              controller: _ntfyTopicUrlController,
              decoration: const InputDecoration(labelText: 'URL do Tópico ntfy.sh'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mapeamento de Dispositivos RF', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addDevice,
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rfDevices.length,
              itemBuilder: (context, index) {
                final device = _rfDevices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text('Código: ${device.code}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editDevice(device),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteDevice(device),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

