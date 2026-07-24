import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'camera_edit_screen.dart';

class CameraListScreen extends StatefulWidget {
  const CameraListScreen({super.key});

  @override
  State<CameraListScreen> createState() => _CameraListScreenState();
}

class _CameraListScreenState extends State<CameraListScreen> {
  late Future<List<Camera>> _camerasFuture;
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  void _loadCameras() {
    setState(() {
      _camerasFuture = _cameraService.getCamerasDynamic();
    });
  }

  void _editCamera(Camera camera) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraEditScreen(camera: camera)),
    );
    if (result == true) {
      _loadCameras(); // Recarrega a lista se uma edição foi feita
    }
  }

  void _deleteCamera(int id) async {
    // Adicionar um diálogo de confirmação para exclusão
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja remover esta câmera?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _cameraService.removeCamera(id);
      if (!mounted) return;
      _loadCameras(); // Recarrega a lista após a exclusão
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera removida com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GERENCIAR CÂMERAS'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: FutureBuilder<List<Camera>>(
        future: _camerasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar câmeras: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma câmera configurada.'));
          }

          final cameras = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: cameras.length,
            itemBuilder: (context, index) {
              final camera = cameras[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  title: Text(camera.name),
                  subtitle: Text(camera.rtspUrl, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editCamera(camera),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCamera(camera.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraEditScreen()),
          );
          if (result == true) {
            _loadCameras(); // Recarrega a lista se uma nova câmera foi adicionada
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
