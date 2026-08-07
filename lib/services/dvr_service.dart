import 'package:http/http.dart' as http;
import '../models/camera.dart';
import '../models/recording.dart';

class DVRService {
  final String dvrAuth = "vtr:vitor6721";
  final String dvrHost = "192.168.15.55:554";
  final String cameraIp = "admin:admin123456@192.168.15.19:8554/profile1";

  // URLs RTSP configuradas
  static const Map<int, String> rtspUrls = {
    1: "rtsp://vtr:vitor6721@sentinelhub.ddns.net:554/?channel=1&stream=0",
    2: "rtsp://vtr:vitor6721@sentinelhub.ddns.net:554/?channel=2&stream=0",
    3: "rtsp://vtr:vitor6721@sentinelhub.ddns.net:554/?channel=3&stream=0",
    4: "rtsp://vtr:vitor6721@sentinelhub.ddns.net:554/?channel=4&stream=0",
  };

  // Câmeras configuradas
  List<Camera> getCameras() {
    return [
      Camera(
        id: 1,
        name: "Câmera DVR CH-1",
        rtspUrl: rtspUrls[1]!,
        description: "Canal 1 - DVR AITEK",
        isActive: true,
      ),
      Camera(
        id: 2,
        name: "Câmera DVR CH-2",
        rtspUrl: rtspUrls[2]!,
        description: "Canal 2 - DVR AITEK",
        isActive: false,
      ),
      Camera(
        id: 3,
        name: "Câmera DVR CH-3",
        rtspUrl: rtspUrls[3]!,
        description: "Canal 3 - DVR AITEK",
        isActive: false,
      ),
      Camera(
        id: 5,
        name: "Câmera IP",
        rtspUrl: "rtsp://admin:admin123456@192.168.15.19:8554/profile1",
        description: "Câmera IP Externa",
        isActive: true,
      ),
    ];
  }

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
      final camera = getCameras().firstWhere((c) => c.id == cameraId);

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
