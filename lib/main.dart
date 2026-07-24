import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:sentinelhubapp/screens/settings_screen.dart';
import 'package:sentinelhubapp/config/app_config.dart';

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
  // Garante que os bindings do Flutter estejam prontos antes de qualquer outra coisa.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      DartVLC.initialize();
    }
  } catch (e) {
    // Se a inicialização do VLC falhar, imprima um erro claro.
    // Isso é útil para diagnosticar a falta de bibliotecas nativas.
    debugPrint('ERRO: Falha ao inicializar o DartVLC. Verifique se as bibliotecas do VLC estão instaladas. Detalhes: $e');
  }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações Gerais',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (result == true && mounted) {
                setState(() => _camerasFuture = _cameraService.getCamerasDynamic());
              }
            },
          ),
        ],
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
class LiveViewScreen extends StatelessWidget {
  final Camera camera;

  const LiveViewScreen({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || Platform.isMacOS) {
      return _UnsupportedPlatformPlayer(cameraName: camera.name);
    }
    if (Platform.isWindows || Platform.isLinux) {
      return _DesktopVlcPlayerScreen(camera: camera);
    }
    return _VlcPlayerScreen(camera: camera);
  }
}

// Widget privado para player desktop com dart_vlc
class _DesktopVlcPlayerScreen extends StatefulWidget {
  final Camera camera;

  const _DesktopVlcPlayerScreen({required this.camera});

  @override
  State<_DesktopVlcPlayerScreen> createState() => _DesktopVlcPlayerScreenState();
}

class _DesktopVlcPlayerScreenState extends State<_DesktopVlcPlayerScreen> {
  late Player _player;
  bool _isPlaying = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Usamos um ID único para evitar conflitos e adicionamos argumentos para estabilidade.
    _player = Player(id: widget.camera.id, commandlineArguments: [
      '--rtsp-tcp', // Força TCP para RTSP, mais confiável que UDP.
      '--network-caching=2000', // Aumenta o buffer de rede.
      '--sout-keep', // Mantém a stream ativa.
    ]);

    // Ouve o stream de playback, que é mais confiável para detectar erros e estados.
    _player.playbackStream.listen((event) {
      if (!mounted) return;
      setState(() {
        // Atualiza o estado de reprodução com base no evento.
        _isPlaying = event.isPlaying;
        if (event.isCompleted) {
          _errorMessage = 'O stream de vídeo foi finalizado inesperadamente.';
        }
      });
    }, onError: (error) {
      // Captura erros que ocorrem durante o playback.
      if (mounted) setState(() => _errorMessage = 'Erro no playback: $error');
    });

    try {
      final media = Media.network(widget.camera.rtspUrl, parse: true);
      _player.open(media, autoStart: true);
    } catch (error) {
      _errorMessage = 'Erro ao abrir RTSP: $error';
    }
  }

  @override
  void dispose() {
    // A ordem correta e segura de descarte.
    try {
      _player.dispose();
    } catch (e) {
      debugPrint('Erro ao descartar o player: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container( // A AppBar foi removida para evitar conflitos de renderização no Linux.
        color: Colors.black,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Só exibe o vídeo se o player estiver ativo e sem erros.
              if (_errorMessage.isEmpty)
                // AbsorbPointer previne que eventos do mouse (cliques, movimentos)
                // cheguem à camada nativa do player, evitando crashes relacionados
                // a bugs de interação no Linux.
                AbsorbPointer(
                  child: Video(player: _player, fit: BoxFit.contain),
                ),
              if (!_isPlaying && _errorMessage.isEmpty)
                const CircularProgressIndicator(color: AppConfig.primaryColor),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Botão de voltar customizado e seguro, sobreposto ao vídeo.
              // O widget Material cria uma superfície de desenho separada,
              // ajudando a isolar o botão do player de vídeo nativo.
              Positioned(
                top: 10,
                left: 10,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Voltar',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                    onPressed: () async {
                      // Solução definitiva para o crash no Linux:
                      // 1. Descarta o player de vídeo nativo de forma segura.
                      // 2. Aguarda um breve momento para o descarte nativo ocorrer.
                      // 3. Navega para a tela anterior.
                      // Isso evita conflitos de renderização entre a UI do Flutter e a view nativa.
                      try {
                        _player.dispose(); // Inicia o descarte (é um método void).
                        // Adiciona um pequeno atraso para garantir que a camada nativa processe o dispose.
                        await Future.delayed(const Duration(milliseconds: 100));
                      } finally {
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget privado que encapsula o player VLC
class _VlcPlayerScreen extends StatefulWidget {
  final Camera camera;

  const _VlcPlayerScreen({required this.camera});

  @override
  State<_VlcPlayerScreen> createState() => _VlcPlayerScreenState();
}

class _VlcPlayerScreenState extends State<_VlcPlayerScreen> {
  late VlcPlayerController _vlcController;
  bool _isPlayerReady = false;
  bool _wasBuffering = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Envolve a inicialização em um try-catch para capturar erros que podem causar crash.
    try {
      _vlcController = VlcPlayerController.network(
        widget.camera.rtspUrl,
        hwAcc: HwAcc.auto, // Usar 'auto' é mais flexível para dispositivos reais. 'disabled' é bom para VMs.
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=2000', // Aumenta o buffer de rede para suavizar o stream.
          ]),
          rtp: VlcRtpOptions([
            '--rtsp-tcp', // Força o uso de TCP para RTSP, mais confiável que UDP em redes instáveis.
          ]),
        ),
      );
      _vlcController.addListener(_playerListener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro crítico ao inicializar o player: $e';
        });
      }
    }
  }

  void _playerListener() {
    if (!mounted) return;

    // Simplifica o listener para ser mais direto e evitar múltiplas lógicas de rebuild.
    setState(() {
      _isPlayerReady = _vlcController.value.isInitialized;
      _wasBuffering = _vlcController.value.isBuffering;
      if (_vlcController.value.hasError && _errorMessage.isEmpty) {
        _errorMessage =
            'Erro ao carregar o vídeo. Verifique a URL RTSP e a conexão de rede.\nDetalhes: ${_vlcController.value.errorDescription}';
      }
    });
  }

  @override
  Future<void> dispose() async {
    _vlcController.removeListener(_playerListener);
    if (await _vlcController.isPlaying() ?? false) {
      await _vlcController.stop();
    }
    await _vlcController.dispose();
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
              if (_errorMessage.isEmpty)
                VlcPlayer(
                  controller: _vlcController,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor)),
                )
              else if (!_isPlayerReady)
                const Center(child: Icon(Icons.videocam_off, color: Colors.grey, size: 50)),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_wasBuffering && _errorMessage.isEmpty)
                const CircularProgressIndicator(color: AppConfig.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget exibido quando a plataforma atual não suporta a visualização de vídeo RTSP (ex: Web).
class _UnsupportedPlatformPlayer extends StatelessWidget {
  final String cameraName;

  const _UnsupportedPlatformPlayer({required this.cameraName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cameraName),
        backgroundColor: AppConfig.cardColor,
      ),
      body: Container(
        color: Colors.black,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'A visualização de câmeras RTSP não é suportada nesta plataforma (Web/macOS). Use Android, iOS, Windows ou Linux.',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}