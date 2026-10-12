import 'package:http/http.dart' as http;
import 'camera_service.dart';
import '../models/recording.dart';

class DVRService {
  // Host do DVR informado em build: --dart-define=DVR_HOST=ip:porta
  static const String dvrHost = String.fromEnvironment('DVR_HOST');

  final CameraService _cameraService = CameraService();

  // Simular busca de gravações do DVR
  // Em produção, isso chamaria a API XMeye do AITEK
  Future<List<Recording>> getRecordings({
    required int cameraId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Simulando uma lista de gravações
      // TODO: Implementar chamada real à API XMeye
      await Future.delayed(const Duration(milliseconds: 500));

      final recordings = <Recording>[];
      final cameras = await _cameraService.getCameras();
      final camera = cameras.firstWhere((c) => c.id == cameraId);

      // Gerar gravações de teste
      for (int i = 0; i < 5; i++) {
        final recordStart = startDate.add(Duration(hours: i * 4));
        final recordEnd = recordStart.add(const Duration(hours: 4));

        recordings.add(Recording(
          id: 'rec_${cameraId}_$i',
          cameraId: cameraId,
          cameraName: camera.name,
          startTime: recordStart,
          endTime: recordEnd,
          sizeBytes: (500 * 1024 * 1024), // 500 MB simulado
          rtspUrl: camera.rtspUrl,
        ));
      }

      return recordings;
    } catch (e) {
      rethrow;
    }
  }

  // Verificar status do DVR
  Future<bool> checkDVRStatus() async {
    if (dvrHost.isEmpty) return false;
    try {
      final response = await http
          .get(Uri.parse('http://$dvrHost/api/status'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
