import 'package:flutter/material.dart';
import 'settings_screen.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'home/camera_grid_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  List<Camera> _cameras = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      // Usar getCameras() que lê do novo sistema unificado se aplicável
      // ou manter o getCamerasDynamic se for o método correto
      final cameras = await _cameraService.getCameras();
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar câmeras: $e')),
        );
      }
    }
  }
  
  void _reloadCameras() {
    setState(() {
      _isLoading = true;
    });
    _loadCameras();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTINEL-HUB'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadCameras,
            tooltip: 'Recarregar Câmeras',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _reloadCameras()); // Recarrega após fechar as configs
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CameraGridPanel(
              cameras: _cameras,
            ),
    );
  }
}
