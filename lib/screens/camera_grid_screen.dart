import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'live_view_screen.dart';

class CameraGridScreen extends StatefulWidget {
  const CameraGridScreen({super.key});

  @override
  State<CameraGridScreen> createState() => _CameraGridScreenState();
}

class _CameraGridScreenState extends State<CameraGridScreen> {
  late CameraService _cameraService;
  late List<Camera> _cameras;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _cameras = _cameraService.getAllCameras();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GRID DE CÂMERAS'),
        backgroundColor: const Color(0xFF1F2233),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _cameras.length,
        itemBuilder: (_, index) {
          final camera = _cameras[index];
          return _buildCameraGridItem(camera);
        },
      ),
    );
  }

  Widget _buildCameraGridItem(Camera camera) {
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
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          border: Border.all(
            color: camera.isActive ? Colors.cyanAccent : Colors.grey,
            width: camera.isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              size: 48,
              color: camera.isActive ? Colors.cyanAccent : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              camera.name,
              style: TextStyle(
                color: camera.isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: camera.isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                camera.isActive ? 'ATIVA' : 'INATIVA',
                style: TextStyle(
                  color: camera.isActive ? Colors.green : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
