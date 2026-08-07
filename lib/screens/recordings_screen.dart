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
  final CameraService _cameraService = CameraService();
  final DVRService _dvrService = DVRService();

  Camera? _selectedCamera;
  List<Camera> _cameras = [];

  late DateTime _selectedDate;
  List<Recording> _recordings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cameras = await _cameraService.getCameras();
      if (!mounted) return;

      setState(() {
        _cameras = cameras;
        if (_cameras.isNotEmpty) {
          _selectedCamera = _cameras.first;
          _fetchRecordings();
        } else {
          _isLoading = false;
          _errorMessage =
              'Nenhuma câmera encontrada. Adicione uma nas configurações.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar câmeras: $e';
      });
    }
  }

  Future<void> _fetchRecordings() async {
    if (_selectedCamera == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final recordings = await _dvrService.getRecordings(
        cameraId: _selectedCamera!.id,
        startDate: _selectedDate,
        endDate: _selectedDate.add(const Duration(days: 1)),
      );
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao buscar gravações: $e';
      });
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
          _buildControls(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
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
          // Usar um DropdownButtonFormField para lidar com estado inicial nulo
          if (_cameras.isNotEmpty)
            DropdownButton<Camera>(
              isExpanded: true,
              value: _selectedCamera,
              dropdownColor: const Color(0xFF1F2233),
              style: const TextStyle(color: Colors.white),
              items: _cameras.map((camera) {
                return DropdownMenuItem(
                  value: camera,
                  child: Text(camera.name),
                );
              }).toList(),
              onChanged: (camera) {
                if (camera != null && camera != _selectedCamera) {
                  setState(() => _selectedCamera = camera);
                  _fetchRecordings();
                }
              },
            )
          else
            const Text(
              'Nenhuma câmera disponível',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_recordings.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recordings.length,
      itemBuilder: (_, index) {
        final recording = _recordings[index];
        return _buildRecordingItem(recording);
      },
    );
  }

  Widget _buildRecordingItem(Recording recording) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2233),
        border: Border.all(color: Colors.orangeAccent.withAlpha(77)),
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
