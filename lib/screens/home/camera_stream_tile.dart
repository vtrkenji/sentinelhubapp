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
        const SnackBar(
            content: Text('Câmera inativa. Ative-a nas configurações.')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _hasError = false;
    });

    try {
      _player = Player(
          configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn));
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      await _player!.setVolume(0);

      final streamUrl = widget.camera.activeRtspUrl;
      if (streamUrl.isEmpty) {
        throw Exception('Nenhuma URL RTSP válida configurada.');
      }
      if (!Camera.isValidRtspUrl(streamUrl)) {
        throw Exception('URL RTSP inválida: $streamUrl');
      }

      if (_player!.platform is NativePlayer) {
        final native = _player!.platform as NativePlayer;
        await native.setProperty('hwdec', 'auto-safe');
        await native.setProperty('force-seekable', 'yes');
        await native.setProperty('untimed', 'yes');
        await native.setProperty('demuxer-lavf-o', 'rtsp_transport=tcp');
        await native.setProperty('network-timeout', '5');
      }

      _player!.stream.error.listen((error) {
        debugPrint('Erro no player da câmera ${widget.camera.name}: $error');
        if (!mounted) return;
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
    if (_player == null || !mounted) return;
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _hasError ? Icons.error_outline : Icons.videocam_off_outlined,
                color: _hasError ? Colors.red : Colors.white70,
                size: 36,
              ),
              const SizedBox(height: 6),
              Text(
                widget.camera.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              if (_hasError)
                const Text('Erro de conexão',
                    style: TextStyle(color: Colors.red, fontSize: 11)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connect,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(_isConnecting ? 'Conectando...' : 'Conectar'),
                style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
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
            if (isBuffering) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Header limpo e sem conflito de layout
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 38,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(200), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _disconnect,
                  iconSize: 18,
                  color: Colors.white,
                  tooltip: 'Parar',
                  style: _compactButtonStyle,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _hasError ? Colors.red : Colors.green.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.camera.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 2.0, color: Colors.black)
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      onPressed: _toggleMute,
                      iconSize: 18,
                      color: Colors.white,
                      style: _compactButtonStyle,
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        );
                      },
                      iconSize: 18,
                      color: Colors.white,
                      style: _compactButtonStyle,
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

  final ButtonStyle _compactButtonStyle = IconButton.styleFrom(
    backgroundColor: Colors.transparent,
    padding: EdgeInsets.zero,
    minimumSize: const Size(28, 28),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
