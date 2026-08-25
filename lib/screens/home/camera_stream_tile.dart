import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../config/app_config.dart';
import '../../models/camera.dart';
import '../../utils/video_controller_config.dart';

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
  static final Set<int> _activeTileIds = <int>{};
  static const int _maxConcurrentStreams = 3;

  Player? _player;
  VideoController? _videoController;

  bool _isPlaying = false;
  bool _isConnecting = false;
  bool _hasError = false;
  bool _isMuted = true;

  Future<void> _connect() async {
    if (_isPlaying || _isConnecting) return;

    if (!widget.camera.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera inativa. Ative-a nas configurações.')),
      );
      return;
    }

    if (_activeTileIds.length >= _maxConcurrentStreams && !_activeTileIds.contains(widget.camera.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de live: apenas 3 câmeras ativas ao mesmo tempo.')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _hasError = false;
    });

    try {
      _activeTileIds.add(widget.camera.id);
      _player = Player(configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn));
      _videoController = VideoController(
        _player!,
        configuration: getVideoControllerConfiguration(),
      );

      await _player!.setVolume(0);

      final streamUrl = widget.camera.activeRtspUrl;
      if (streamUrl.isEmpty) {
        throw Exception('Nenhuma URL RTSP válida configurada.');
      }
      if (!Camera.isValidRtspUrl(streamUrl)) {
        throw Exception('URL RTSP inválida: $streamUrl');
      }

      try {
        if (!kIsWeb) {
          final dynamic native = _player!.platform;
          if (native.runtimeType.toString() == 'NativePlayer') {
            await native.setProperty('hwdec', 'auto-safe');
            await native.setProperty('force-seekable', 'yes');
            await native.setProperty('untimed', 'yes');
            await native.setProperty('demuxer-lavf-o', 'rtsp_transport=tcp');
            await native.setProperty('network-timeout', '5');
          }
        }
      } catch (e) {
        debugPrint('Erro ao definir propriedades nativas: $e');
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
      _activeTileIds.remove(widget.camera.id);
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
    _activeTileIds.remove(widget.camera.id);
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
  void dispose() {
    _activeTileIds.remove(widget.camera.id);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0C171D),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.white.withAlpha(10), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _isPlaying && _videoController != null
          ? _buildPlayerView()
          : _buildConnectView(),
    );
  }

  Widget _buildConnectView() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasError ? Icons.error_outline : Icons.videocam_off_outlined,
            color: _hasError ? AppConfig.alertColor : AppConfig.accentColor.withValues(alpha: 0.92),
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            widget.camera.name,
            style: const TextStyle(
              color: AppConfig.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (_hasError)
            const Text(
              'Erro de conexão',
              style: TextStyle(color: AppConfig.alertColor, fontSize: 11),
            ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : _connect,
            icon: _isConnecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 16),
            label: Text(_isConnecting ? 'Conectando...' : 'Conectar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 11),
              backgroundColor: AppConfig.accentColor,
              foregroundColor: AppConfig.backgroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppConfig.backgroundColor),
        Video(controller: _videoController!, fit: BoxFit.cover),

        if (_hasError)
          Container(
            color: AppConfig.backgroundColor.withValues(alpha: 0.75),
            alignment: Alignment.center,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Erro ao exibir vídeo.\nVerifique a câmera e a conexão.',
                style: TextStyle(color: AppConfig.textColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),

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
                colors: [AppConfig.backgroundColor.withAlpha(220), AppConfig.backgroundColor.withAlpha(0)],
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
                          color: _hasError ? AppConfig.alertColor : AppConfig.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.camera.name,
                          style: const TextStyle(
                            color: AppConfig.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [
                              Shadow(blurRadius: 2.0, color: AppConfig.backgroundColor),
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
                      color: AppConfig.textColor,
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
