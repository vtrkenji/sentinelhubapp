import 'package:flutter/material.dart';
import 'settings_screen.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'home/camera_grid_panel.dart';
import 'home/settings_and_logs_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  List<Camera> _cameras = [];
  Camera? _cameraToConfigure;
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await _cameraService.getCamerasDynamic();
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

  void _onConfigureCamera(Camera camera) {
    setState(() {
      _cameraToConfigure = camera;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _onCameraSettingsChanged(Camera updatedCamera) {
    // Atualiza a lista local e o estado para refletir a mudança imediatamente
    final index = _cameras.indexWhere((c) => c.id == updatedCamera.id);
    if (index != -1) {
      setState(() {
        _cameras[index] = updatedCamera;
        _cameraToConfigure = updatedCamera;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('SENTINEL-HUB // ENGENHARIA'),
        backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CameraGridPanel(
              cameras: _cameras,
              onConfigureCamera: _onConfigureCamera,
            ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.35, // Ocupa 35% da tela
        child: SettingsAndLogsPanel(
          key: ValueKey(_cameraToConfigure?.id), // Garante que o painel reconstrua ao mudar de câmera
          selectedCamera: _cameraToConfigure,
          onCameraSettingsChanged: _onCameraSettingsChanged,
        ),
      ),
    );
  }
}
