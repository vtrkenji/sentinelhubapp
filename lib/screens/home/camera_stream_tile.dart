import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/camera.dart';

class CameraStreamTile extends StatefulWidget {
  final Camera camera;

  const CameraStreamTile({required this.camera, super.key});

  @override
  State<CameraStreamTile> createState() => _CameraStreamTileState();
}

class _CameraStreamTileState extends State<CameraStreamTile> {
  Player? _player;
  VideoController? _videoController;
  bool _isPlaying = false;
  bool _isConnecting = false; // To show a loading indicator on the button

  @override
  void dispose() {
    // Apenas libera os recursos do player de forma síncrona.
    _player?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isPlaying || _isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      // 1. Instancia o player e o controller
      _player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          bufferSize: 1024 * 1024, // 1 MB
          libass: false,
        ),
      );
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );

      // 2. Aplica os parâmetros via CPU (sem CUDA)
      if (_player!.platform is NativePlayer) {
        final native = _player!.platform as NativePlayer;
        await native.setProperty('hwdec', 'no');
        await native.setProperty('rtsp_transport', 'tcp');
        await native.setProperty('network-caching', '100');
      }

      // 3. Abre a stream RTSP
      await _player!.open(Media(widget.camera.rtspUrl), play: true);
      
      // 4. Atualiza o estado para exibir o vídeo
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _isConnecting = false;
      });

    } catch (e) {
      debugPrint('Erro ao inicializar o player RTSP: $e');
      if (!mounted) return;
      // Em caso de erro, reverte o estado
      setState(() {
        _isConnecting = false;
      });
      // Opcional: mostrar um snackbar ou um dialog de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao conectar à câmera: ${e.toString()}')),
      );
    }
  }

  void _disconnect() {
    _player?.dispose();
    if (mounted) {
      setState(() {
        _player = null;
        _videoController = null;
        _isPlaying = false;
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.black,
      child: _isPlaying && _videoController != null
          ? _buildPlayerView()
          : _buildConnectView(),
    );
  }

  Widget _buildConnectView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              widget.camera.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isConnecting ? 'Conectando...' : 'Conectar Câmera'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView() {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        StreamBuilder<Object>(
          stream: _player!.stream.error,
          builder: (context, errorSnapshot) {
            if (errorSnapshot.hasData) {
              return _buildErrorWidget(errorSnapshot.data.toString());
            }
            return StreamBuilder<bool>(
              stream: _player!.stream.buffering,
              builder: (context, bufferingSnapshot) {
                final isBuffering = bufferingSnapshot.data ?? true;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Video(controller: _videoController!, fit: BoxFit.cover),
                    if (isBuffering) const CircularProgressIndicator(),
                  ],
                );
              },
            );
          },
        ),
        // Botão para desconectar
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
            onPressed: _disconnect,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Overlay com o nome da câmera
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Colors.black.withOpacity(0.6),
            child: Text(
              widget.camera.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    // Reutiliza o view de conexão com uma mensagem de erro
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(
            'Erro ao carregar stream',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _disconnect,
            child: const Text('Tentar Novamente'),
          )
        ],
      ),
    );
  }
}
