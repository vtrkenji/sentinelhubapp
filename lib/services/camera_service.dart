import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/camera.dart';

class CameraService {
  static const String _camerasKey = 'saved_cameras';

  // Retorna a lista de câmeras de forma síncrona (usando os valores padrão do AppConfig)
  // Este método pode ser removido ou refatorado se a ideia é ter apenas câmeras configuráveis.
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

  // Versão assíncrona que lê as câmeras salvas pelo usuário no SharedPreferences
  Future<List<Camera>> getCamerasDynamic() async {
    final prefs = await SharedPreferences.getInstance();
    final String? camerasJson = prefs.getString(_camerasKey);

    if (camerasJson != null) {
      final List<dynamic> decodedData = json.decode(camerasJson);
      return decodedData.map((json) => Camera.fromJson(json)).toList();
    }

    // Se não houver câmeras salvas, retorna uma lista padrão (opcional, pode ser vazia)
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

  // Novo método para salvar a lista de câmeras no SharedPreferences
  Future<void> saveCameras(List<Camera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = cameras.map((camera) => camera.toJson()).toList();
    await prefs.setString(_camerasKey, json.encode(jsonList));
  }

  // Método para adicionar uma nova câmera (pode ser usado na tela de configurações)
  Future<void> addCamera(Camera camera) async {
    List<Camera> currentCameras = await getCamerasDynamic();
    // Garante que a nova câmera tenha um ID único
    int newId = currentCameras.isEmpty ? 1 : currentCameras.map((c) => c.id).reduce(math.max) + 1;
    final cameraWithId = Camera(
      id: newId,
      name: camera.name,
      rtspUrl: camera.rtspUrl,
      description: camera.description,
      isActive: camera.isActive,
    );
    currentCameras.add(cameraWithId);
    await saveCameras(currentCameras);
  }

  // Método para atualizar uma câmera existente
  Future<void> updateCamera(Camera updatedCamera) async {
    List<Camera> currentCameras = await getCamerasDynamic();
    int index = currentCameras.indexWhere((c) => c.id == updatedCamera.id);
    if (index != -1) {
      currentCameras[index] = updatedCamera;
      await saveCameras(currentCameras);
    }
  }

  // Método para remover uma câmera
  Future<void> removeCamera(int id) async {
    List<Camera> currentCameras = await getCamerasDynamic();
    currentCameras.removeWhere((c) => c.id == id);
    await saveCameras(currentCameras);
  }
}