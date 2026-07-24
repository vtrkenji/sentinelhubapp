import 'package:flutter/material.dart';
import '../../models/camera.dart';
import '../../services/camera_service.dart';
import 'camera_stream_tile.dart';

class OperationPanel extends StatefulWidget {
  const OperationPanel({super.key});

  @override
  State<OperationPanel> createState() => _OperationPanelState();
}

class _OperationPanelState extends State<OperationPanel> {
  late Future<List<Camera>> _camerasFuture;
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _camerasFuture = _cameraService.getCamerasDynamic();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Camera>>(
      future: _camerasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar câmeras: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma câmera encontrada. Adicione câmeras no Modo Engenharia > Configurações.'));
        }

        final cameras = snapshot.data!;
        
        // Utiliza DefaultTabController para gerenciar o estado das abas
        return DefaultTabController(
          length: cameras.length,
          child: Column(
            children: [
              // Abas com os nomes das câmeras
              TabBar(
                isScrollable: true,
                tabs: cameras.map((camera) => Tab(text: camera.name)).toList(),
              ),
              // Conteúdo de cada aba
              Expanded(
                child: TabBarView(
                  // Para cada câmera, cria um CameraStreamTile correspondente
                  // A TabBarView gerencia o estado, destruindo os inativos
                  children: cameras.map((camera) {
                    // Usar uma Key garante que o Flutter identifique corretamente
                    // os widgets quando a lista de câmeras mudar
                    return CameraStreamTile(key: ValueKey(camera.id), camera: camera);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
