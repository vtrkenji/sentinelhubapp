import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sentinel_hub/screens/settings_screen.dart';
import '../../models/camera.dart';

class CameraStreamTile extends StatefulWidget {
  final Camera camera;

  const CameraStreamTile({
    required this.camera,
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
  bool _isMuted = true;

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

      // Garante que o player inicie mutado
      await _player!.setVolume(0);

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

  void _toggleMute() {
    if (_player == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _player!.setVolume(_isMuted ? 0 : 100);
    });
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
      fit: StackFit.expand,
      children: [
        Video(controller: _videoController!, fit: BoxFit.cover),
        
        StreamBuilder<bool>(
          stream: _player!.stream.buffering,
          builder: (context, snapshot) {
            final isBuffering = snapshot.data ?? false;
            if (isBuffering) return const Center(child: CircularProgressIndicator());
            return const SizedBox.shrink();
          },
        ),

        // Header Unificado
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Botão Stop
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _disconnect,
                  iconSize: 20,
                  color: Colors.white,
                  tooltip: 'Parar',
                  style: _iconButtonStyle,
                ),

                // 2. Status e Nome da Câmera (Centralizado e Flexível)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _hasError ? Colors.red : Colors.green.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.camera.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [Shadow(blurRadius: 1.0, color: Colors.black)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Botões de Ação (Direita)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      onPressed: _toggleMute,
                      iconSize: 20,
                      color: Colors.white,
                      tooltip: _isMuted ? 'Ativar Som' : 'Desativar Som',
                      style: _iconButtonStyle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                      iconSize: 20,
                      color: Colors.white,
                      tooltip: 'Configurações',
                      style: _iconButtonStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Estilo compartilhado para os IconButtons
  final ButtonStyle _iconButtonStyle = IconButton.styleFrom(
    backgroundColor: Colors.black.withOpacity(0.3),
    padding: const EdgeInsets.all(6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
