import 'package:flutter/material.dart';
import 'home/operation_panel.dart';
import 'home/engineering_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isEngineeringMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEngineeringMode ? 'SENTINEL-HUB // ENGENHARIA' : 'SENTINEL-HUB'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        elevation: 1,
        actions: [
          const Text('Modo Eng.'),
          Switch(
            value: _isEngineeringMode,
            onChanged: (value) {
              setState(() {
                _isEngineeringMode = value;
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isEngineeringMode ? const EngineeringPanel() : const OperationPanel(),
    );
  }
}
