import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/camera.dart';

class CameraService {
  // Retorna a lista de câmeras de forma síncrona (usando os valores padrão do AppConfig)
  List<Camera> getAllCameras() {
    return [
      Camera(
        id: 1,
        name: 'DVR Aitek (Canal 1)',
        rtspUrl: 'rtsp://${AppConfig.dvrUsername}:${AppConfig.dvrPassword}@${AppConfig.dvrHost}/?channel=1&stream=0',
        description: 'Câmera principal do DVR',
        isActive: true,
      ),
      Camera(
        id: 2,
        name: 'Câmera IP Local',
        rtspUrl: 'rtsp://${AppConfig.cameraIpUsername}:${AppConfig.cameraIpPassword}@${AppConfig.cameraIpHost}/profile1',
        description: 'Câmera IP independente',
        isActive: true,
      ),
    ];
  }

  // Versão assíncrona que lê as alterações salvas pelo usuário no SharedPreferences
  Future<List<Camera>> getCamerasDynamic() async {
    final prefs = await SharedPreferences.getInstance();

    final dvrHost = prefs.getString('dvr_host') ?? AppConfig.dvrHost;
    final dvrUser = prefs.getString('dvr_user') ?? AppConfig.dvrUsername;
    final dvrPass = prefs.getString('dvr_pass') ?? AppConfig.dvrPassword;

    final ipHost = prefs.getString('ip_host') ?? AppConfig.cameraIpHost;
    final ipUser = prefs.getString('ip_user') ?? AppConfig.cameraIpUsername;
    final ipPass = prefs.getString('ip_pass') ?? AppConfig.cameraIpPassword;

    return [
      Camera(
        id: 1,
        name: 'DVR Aitek (Canal 1)',
        rtspUrl: 'rtsp://$dvrUser:$dvrPass@$dvrHost/?channel=1&stream=0',
        description: 'Câmera principal do DVR',
        isActive: true,
      ),
      Camera(
        id: 2,
        name: 'Câmera IP Local',
        rtspUrl: 'rtsp://$ipUser:$ipPass@$ipHost/profile1',
        description: 'Câmera IP independente',
        isActive: true,
      ),
    ];
  }
}