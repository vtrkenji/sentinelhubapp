import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/camera.dart';

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

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        // FIX: Desativa a aceleração por hardware para evitar crashes de driver no Linux.
        enableHardwareAcceleration: false,
      ),
    );

    // FIX: Evita crash da thread de renderização no Linux
    if (_player.platform is NativePlayer) {
      await (_player.platform as NativePlayer).setProperty('hwdec', 'auto-safe');
    }
    
    // Conecta-se à stream principal (alta resolução)
    await _player.open(Media(widget.camera.rtspUrl), play: true);
    if(mounted) {
      setState(() {
        _isInitialized = true;
      });
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
        title: Text('AO VIVO: ${widget.camera.name}'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _isInitialized
            ? Video(
                controller: _videoController,
                fit: BoxFit.contain,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
