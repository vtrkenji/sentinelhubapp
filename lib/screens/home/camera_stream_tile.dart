import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/camera.dart';

class CameraStreamTile extends StatefulWidget {
  final Camera camera;
  final VoidCallback onConfigure;

  const CameraStreamTile({
    required this.camera,
    required this.onConfigure,
    super.key,
  });

  @override
  State<CameraStreamTile> createState() => _CameraStreamTileState();
}

class _CameraStreamTileState extends State<CameraStreamTile> {
  Player? _player;
  VideoController? _videoController;

  bool _isPlaying = false;
  bool _isConnecting = false;
  bool _hasError = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isPlaying || _isConnecting) return;

    if (!widget.camera.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera inativa. Ative-a nas configurações.')),
      );
      return;
    }
    
    setState(() {
      _isConnecting = true;
      _hasError = false;
    });

    try {
      _player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn));
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          // FIX: Desativa a aceleração por hardware para evitar crashes de driver no Linux.
          // A renderização via software (CPU) é mais estável para streams de baixa FPS.
          enableHardwareAcceleration: false,
        ),
      );

      // Prioriza a stream secundária para a grade
      final streamUrl = widget.camera.rtspUrlSecondary?.isNotEmpty == true
          ? widget.camera.rtspUrlSecondary!
          : widget.camera.rtspUrl;

      if (streamUrl.isEmpty) {
        throw Exception('Nenhuma URL RTSP válida configurada.');
      }
      
      // FIX: Evita crash da thread de renderização no Linux
      if (_player!.platform is NativePlayer) {
        await (_player!.platform as NativePlayer).setProperty('hwdec', 'auto-safe');
      }

      _player!.stream.error.listen((error) {
        debugPrint('Erro no player da câmera ${widget.camera.name}: $error');
        if (!mounted) return;
        // Garante que a atualização de estado ocorra na thread da UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _hasError = true);
          }
        });
      });
      
      await _player!.open(Media(streamUrl), play: true);

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isConnecting = false;
          _isPlaying = false;
        });
      }
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
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.white12, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _isPlaying && _videoController != null
          ? _buildPlayerView()
          : _buildConnectView(),
    );
  }

  Widget _buildConnectView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _hasError ? Icons.error_outline : Icons.videocam_off_outlined,
          color: _hasError ? Colors.red : Colors.white70,
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          widget.camera.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (_hasError)
          const Text('Erro de conexão', style: TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isConnecting ? null : _connect,
          icon: _isConnecting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow, size: 18),
          label: Text(_isConnecting ? 'Conectando...' : 'Conectar Câmera'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(fontSize: 12)
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerView() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Video(controller: _videoController!, fit: BoxFit.cover),
        
        StreamBuilder<bool>(
          stream: _player!.stream.buffering,
          builder: (context, snapshot) {
            final isBuffering = snapshot.data ?? false;
            if (isBuffering) return const CircularProgressIndicator();
            return const SizedBox.shrink();
          },
        ),

        // Overlay Superior: Ícones
        Positioned(
          top: 4,
          right: 4,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sub-stream // 15 FPS // 512 Kbps',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: widget.onConfigure,
                iconSize: 18,
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Botão para desconectar
        Positioned(
          top: 4,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _disconnect,
            iconSize: 18,
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        
        // Overlay Inferior: Nome e Status
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: Colors.black.withOpacity(0.7),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _hasError ? Colors.red : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.camera.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
