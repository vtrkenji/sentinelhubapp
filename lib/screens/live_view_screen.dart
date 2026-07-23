import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import '../models/camera.dart';

class LiveViewScreen extends StatefulWidget {
  final Camera camera;

  const LiveViewScreen({required this.camera, super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  late BetterPlayerController _betterPlayerController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    try {
      final betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enablePlayPause: true,
          enableMute: true,
          enableFullscreen: true,
          enableProgressBar: false,
          controlBarHeight: 48,
          iconsColor: Colors.cyanAccent,
          textColor: Colors.white,
          backgroundColor: Colors.black87,
        ),
      );

      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.camera.rtspUrl,
        liveStream: true,
      );

      _betterPlayerController.setupDataSource(dataSource);

      _betterPlayerController.addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Erro ao conectar: ${event.parameters?['exception'] ?? 'Desconhecido'}';
              _isLoading = false;
            });
          }
        }
      });

      // Timeout se não conectar em 15 segundos
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isLoading) {
          setState(() {
            _errorMessage = 'Timeout ao conectar ao stream';
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao inicializar: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.camera.name),
        backgroundColor: const Color(0xFF1F2233),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _errorMessage != null
                ? Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _initializePlayer();
                            },
                            child: const Text('RECONECTAR'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isLoading
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.cyanAccent),
                              SizedBox(height: 16),
                              Text(
                                'Conectando câmera...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : BetterPlayer(controller: _betterPlayerController),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1F2233),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('VOLTAR'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}