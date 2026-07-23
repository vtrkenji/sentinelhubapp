import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../models/recording.dart';
import '../services/camera_service.dart';
import '../services/dvr_service.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  late CameraService _cameraService;
  late DVRService _dvrService;
  late Camera _selectedCamera;
  late DateTime _selectedDate;
  List<Recording> _recordings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _dvrService = DVRService();
    _selectedCamera = _cameraService.getAllCameras().first;
    _selectedDate = DateTime.now();
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    setState(() => _isLoading = true);
    try {
      final recordings = await _dvrService.getRecordings(
        cameraId: _selectedCamera.id,
        startDate: _selectedDate,
        endDate: _selectedDate.add(const Duration(days: 1)),
      );
      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GRAVAÇÕES'),
        backgroundColor: const Color(0xFF1F2233),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1F2233),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CÂMERA',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<Camera>(
                  isExpanded: true,
                  value: _selectedCamera,
                  dropdownColor: const Color(0xFF1F2233),
                  style: const TextStyle(color: Colors.white),
                  items: _cameraService.getAllCameras().map((camera) {
                    return DropdownMenuItem(
                      value: camera,
                      child: Text(camera.name),
                    );
                  }).toList(),
                  onChanged: (camera) {
                    if (camera != null) {
                      setState(() => _selectedCamera = camera);
                      _fetchRecordings();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : _recordings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 64,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma gravação encontrada',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _recordings.length,
                        itemBuilder: (_, index) {
                          final recording = _recordings[index];
                          return _buildRecordingItem(recording);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingItem(Recording recording) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2233),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle, color: Colors.orangeAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${recording.startTime.hour.toString().padLeft(2, '0')}:${recording.startTime.minute.toString().padLeft(2, '0')} - ${recording.endTime.hour.toString().padLeft(2, '0')}:${recording.endTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tamanho: ${recording.formattedSize}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
