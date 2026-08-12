import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../config/app_config.dart';
import '../models/camera.dart';
import '../utils/video_controller_config.dart';

class LiveViewScreen extends StatefulWidget {
  final Camera camera;

  const LiveViewScreen({required this.camera, super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  late final Player _player;
  late final VideoController _videoController;

  @override
  void initState() {
    super.initState();
    // 1. Instancia o player básico
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: getVideoControllerConfiguration(),
    );

    // 2. Inicialização assíncrona garantindo o CPU decoding prévio
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // 3. Aplica os parâmetros sem CUDA com AWAIT
      if (!kIsWeb) {
        // ignore: avoid_dynamic_calls
        final dynamic native = _player.platform;
        if (native.runtimeType.toString() == 'NativePlayer') {
          await native.setProperty('hwdec', 'no');
          await native.setProperty('rtsp_transport', 'tcp');
          await native.setProperty('network-caching', '100');
        }
      }

      // 4. Abre o stream em tela cheia apenas após aplicar as flags
      await _player.open(Media(widget.camera.rtspUrl), play: true);
    } catch (e) {
      debugPrint('Erro ao inicializar LiveView RTSP: $e');
      if (!mounted) return;
      // Opcional: Mostrar um erro para o usuário se o widget ainda estiver montado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar o vídeo: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.camera.name),
        backgroundColor: AppConfig.cardColor,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppConfig.backgroundColor),
          StreamBuilder<Object>(
            stream: _player.stream.error,
            builder: (context, errorSnapshot) {
              if (errorSnapshot.hasData) {
                return Center(
                    child: Text('Erro: ${errorSnapshot.data.toString()}'));
              }
              return StreamBuilder<bool>(
                stream: _player.stream.buffering,
                builder: (context, bufferingSnapshot) {
                  final isBuffering = bufferingSnapshot.data ?? true;
                  if (isBuffering) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Video(controller: _videoController);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
