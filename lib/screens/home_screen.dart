import 'package:flutter/material.dart';
import '../services/ntfy_service.dart';
import '../services/camera_service.dart';
import '../models/alert_event.dart';
import '../models/camera.dart';
import 'live_view_screen.dart';
import 'camera_grid_screen.dart';
import 'recordings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late NtfyService _ntfyService;
  late CameraService _cameraService;
  AlertEvent? _lastAlert;
  bool _isAlertActive = false;

  @override
  void initState() {
    super.initState();
    _ntfyService = NtfyService();
    _cameraService = CameraService();

    _ntfyService.startListening();
    _ntfyService.alertStream.listen((alert) {
      setState(() {
        _lastAlert = alert;
        _isAlertActive = true;
      });

      // Auto-reset após 10 segundos
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isAlertActive = false);
        }
      });
    });
  }

  @override
  void dispose() {
    _ntfyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameras = _cameraService.getActiveCameras();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTINEL-HUB // MONITOR'),
        backgroundColor: const Color(0xFF1F2233),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card - Alerta
              _buildAlertCard(),
              const SizedBox(height: 20),

              // Grid de Ações Rápidas
              _buildQuickActionsGrid(cameras),
              const SizedBox(height: 20),

              // Câmeras Ativas
              _buildCamerasSection(cameras),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2233),
        border: Border.all(
          color: _isAlertActive ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.3),
          width: _isAlertActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS DO GATILHO',
            style: TextStyle(
              fontSize: 12,
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAlertActive
                ? (_lastAlert?.message ?? 'EVENTO DETECTADO')
                : 'Aguardando sinal...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isAlertActive ? Colors.redAccent : Colors.grey,
            ),
          ),
          if (_isAlertActive && _lastAlert != null) ...[
            const SizedBox(height: 8),
            Text(
              'Às ${_lastAlert!.timestamp.hour.toString().padLeft(2, '0')}:${_lastAlert!.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(List<Camera> cameras) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionButton(
          title: 'AO VIVO',
          icon: Icons.videocam,
          color: Colors.cyanAccent,
          onTap: () {
            if (cameras.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveViewScreen(camera: cameras.first),
                ),
              );
            }
          },
        ),
        _buildActionButton(
          title: 'GRAVAÇÕES',
          icon: Icons.storage,
          color: Colors.orangeAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingsScreen()),
            );
          },
        ),
        _buildActionButton(
          title: 'GRID',
          icon: Icons.grid_4x4,
          color: Colors.purple.shade400,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraGridScreen()),
            );
          },
        ),
        _buildActionButton(
          title: 'DISPARAR',
          icon: Icons.bolt,
          color: Colors.redAccent,
          onTap: () => _triggerManualAlert(),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2233),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamerasSection(List<Camera> cameras) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CÂMERAS ATIVAS',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cameras.length,
          itemBuilder: (_, index) {
            final camera = cameras[index];
            return _buildCameraItem(camera);
          },
        ),
      ],
    );
  }

  Widget _buildCameraItem(Camera camera) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveViewScreen(camera: camera),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2233),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.cyanAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (camera.description != null)
                    Text(
                      camera.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.cyanAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerManualAlert() async {
    try {
      await _ntfyService.triggerAlert('Alerta acionado manualmente via Sentinel-Hub!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta disparado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
