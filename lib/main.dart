import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

// --- CONFIGURAÇÕES PADRÃO ---
class AppConfig {
  static const String defaultDvrUrl = 'rtsp://vtr:vitor6721@sentinelhub.ddns.net:554/cam/realmonitor?channel=1&subtype=1';
  static const String defaultIpCamUrl = 'rtsp://admin:admin123456@192.168.15.19:8554/h264Preview_01_main';

  static const Color primaryColor = Color(0xFF00E5FF);
  static const Color backgroundColor = Color(0xFF0F111A);
  static const Color cardColor = Color(0xFF1F2233);
}

// --- MODELO DE CÂMERA ---
class Camera {
  final int id;
  final String name;
  final String rtspUrl;
  final String? description;
  final bool isActive;

  const Camera({
    required this.id,
    required this.name,
    required this.rtspUrl,
    this.description,
    this.isActive = true,
  });
}

// --- SERVIÇO DE CÂMERAS ---
class CameraService {
  Future<List<Camera>> getCamerasDynamic() async {
    final prefs = await SharedPreferences.getInstance();

    final dvrUrl = prefs.getString('camera_url_1') ?? AppConfig.defaultDvrUrl;
    final ipUrl = prefs.getString('camera_url_2') ?? AppConfig.defaultIpCamUrl;

    return [
      Camera(
        id: 1,
        name: 'DVR Principal',
        rtspUrl: dvrUrl,
        description: 'DVR Aitek principal via DDNS',
        isActive: true,
      ),
      Camera(
        id: 2,
        name: 'Câmera IP',
        rtspUrl: ipUrl,
        description: 'Câmera IP da rede',
        isActive: true,
      ),
    ];
  }
}

void main() {
  runApp(const SentinelApp());
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel-Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: AppConfig.primaryColor,
        scaffoldBackgroundColor: AppConfig.backgroundColor,
      ),
      home: const CameraGridScreen(),
    );
  }
}

// --- DASHBOARD / GRID DE CÂMERAS ---
class CameraGridScreen extends StatefulWidget {
  const CameraGridScreen({super.key});

  @override
  State<CameraGridScreen> createState() => _CameraGridScreenState();
}

class _CameraGridScreenState extends State<CameraGridScreen> {
  late Future<List<Camera>> _camerasFuture;
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _camerasFuture = _cameraService.getCamerasDynamic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTINEL-HUB // MONITOR'),
        backgroundColor: AppConfig.cardColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: FutureBuilder<List<Camera>>(
                future: _camerasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro ao carregar câmeras: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhuma câmera encontrada.'));
                  }

                  final cameras = snapshot.data!;
                  return ListView.builder(
                    itemCount: cameras.length,
                    itemBuilder: (context, index) {
                      final cam = cameras[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppConfig.cardColor,
                          border: Border.all(color: AppConfig.primaryColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.videocam, color: AppConfig.primaryColor, size: 32),
                          title: Text(cam.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(cam.rtspUrl, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings, color: Colors.cyanAccent),
                                tooltip: 'Editar Link RTSP',
                                onPressed: () async {
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => EditCameraScreen(camera: cam)),
                                  );
                                  if (updated == true) {
                                    setState(() {
                                      _camerasFuture = _cameraService.getCamerasDynamic();
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConfig.primaryColor,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => LiveViewScreen(camera: cam)));
                                },
                                child: const Text('ABRIR'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConfig.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConfig.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('STATUS DO GATILHO', style: TextStyle(fontSize: 12, color: AppConfig.primaryColor)),
                        SizedBox(height: 4),
                        Text('Aguardando sinal...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.bolt),
                      label: const Text('ACIONAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA DE EDIÇÃO DA URL RTSP INDIVIDUAL ---
class EditCameraScreen extends StatefulWidget {
  final Camera camera;

  const EditCameraScreen({required this.camera, super.key});

  @override
  State<EditCameraScreen> createState() => _EditCameraScreenState();
}

class _EditCameraScreenState extends State<EditCameraScreen> {
  late TextEditingController _urlController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.camera.rtspUrl);
  }

  Future<void> _saveUrl() async {
    if (_formKey.currentState?.validate() ?? false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('camera_url_${widget.camera.id}', _urlController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL RTSP atualizada com sucesso!'),
          backgroundColor: AppConfig.primaryColor,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EDITAR: ${widget.camera.name}'),
        backgroundColor: AppConfig.cardColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'URL RTSP Completa:',
                style: TextStyle(color: AppConfig.primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'rtsp://usuario:senha@ip_ou_dominio:porta/caminho',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A URL não pode estar vazia.';
                  }
                  if (!value.trim().startsWith('rtsp://')) {
                    return 'A URL deve começar com rtsp://';
                  }
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveUrl,
                child: const Text('SALVAR URL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TELA DE PLAYER MULTIPLATAFORMA INTELIGENTE ---
class LiveViewScreen extends StatefulWidget {
  final Camera camera;

  const LiveViewScreen({required this.camera, super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenStateVlc();
}

class _LiveViewScreenStateVlc extends State<LiveViewScreen> {
  late VlcPlayerController _vlcController;
  bool _isPlayerReady = false;
  bool _wasBuffering = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _vlcController = VlcPlayerController.network(
      widget.camera.rtspUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          '--network-caching=2000',
        ]),
        rtp: VlcRtpOptions([
          '--rtsp-tcp',
        ]),
      ),
    );
    _vlcController.addListener(_playerListener);
  }

  void _playerListener() {
    if (!mounted) return;

    bool needsRebuild = false;

    if (_vlcController.value.hasError && _errorMessage.isEmpty) {
      _errorMessage =
          'Erro ao carregar o vídeo. Verifique a URL RTSP e a conexão de rede.\nDetalhes: ${_vlcController.value.errorDescription}';
      needsRebuild = true;
    }

    if (_vlcController.value.isInitialized && !_isPlayerReady) {
      _isPlayerReady = true;
      needsRebuild = true;
    }

    if (_vlcController.value.isBuffering != _wasBuffering) {
      _wasBuffering = _vlcController.value.isBuffering;
      needsRebuild = true;
    }

    if (needsRebuild) setState(() {});
  }

  @override
  void dispose() {
    _vlcController.removeListener(_playerListener);
    _vlcController.stop();
    _vlcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.camera.name),
        backgroundColor: AppConfig.cardColor,
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              VlcPlayer(
                controller: _vlcController,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor)),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_vlcController.value.isBuffering)
                const CircularProgressIndicator(color: AppConfig.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
