import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../config/app_config.dart';
import '../../models/camera.dart';
import '../../utils/video_controller_config.dart';

class FocusedLiveViewScreen extends StatefulWidget {
  final Camera camera;

  const FocusedLiveViewScreen({super.key, required this.camera});

  @override
  State<FocusedLiveViewScreen> createState() => _FocusedLiveViewScreenState();
}

class _FocusedLiveViewScreenState extends State<FocusedLiveViewScreen> {
  late final Player _player;
  late final VideoController _videoController;
  bool _isInitialized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final streamUrl = widget.camera.activeRtspUrl;
    if (!Camera.isValidRtspUrl(streamUrl)) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
      return;
    }

    _player = Player();
    _videoController = VideoController(
      _player,
      configuration: getVideoControllerConfiguration(),
    );

    try {
      if (!kIsWeb) {
        final dynamic native = _player.platform;
        if (native.runtimeType.toString() == 'NativePlayer') {
          await native.setProperty('hwdec', 'auto-safe');
        }
      }

      await _player.open(Media(streamUrl), play: true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Erro ao inicializar a câmera ${widget.camera.name}: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _actionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        border: Border.all(color: AppConfig.accentColor.withAlpha(120)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppConfig.accentColor, size: 18),
        splashRadius: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = Camera.isValidRtspUrl(widget.camera.activeRtspUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF07141A),
        elevation: 0,
        title: Text(
          widget.camera.name,
          style: const TextStyle(
            color: AppConfig.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFullScreen,
            icon: Icon(_isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
            tooltip: 'Tela cheia',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleFullScreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            if (hasValidUrl && _isInitialized)
              Video(
                controller: _videoController,
                fit: BoxFit.cover,
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 48,
                        color: AppConfig.alertColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasValidUrl
                            ? 'A câmera está indisponível no momento.'
                            : 'URL RTSP inválida ou não configurada.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppConfig.textColor, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('VOLTAR'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isFullScreen)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        border: Border.all(color: AppConfig.accentColor.withAlpha(120)),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded, color: AppConfig.accentColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        border: Border.all(color: AppConfig.accentColor.withAlpha(120)),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings_outlined, color: AppConfig.accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(130),
                  border: Border.all(color: AppConfig.accentColor.withAlpha(80)),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppConfig.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
