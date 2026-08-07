import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'camera_edit_screen.dart';
import '../models/hardware_module.dart';
import '../services/module_service.dart';
import 'module_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Camera state
  late Future<List<Camera>> _camerasFuture;
  final CameraService _cameraService = CameraService();

  // Module state
  late Future<List<HardwareModule>> _modulesFuture;
  final ModuleService _moduleService = ModuleService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadCameras();
    _loadModules();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadCameras() {
    setState(() {
      _camerasFuture = _cameraService.getCameras();
    });
  }

  void _loadModules() {
    setState(() {
      _modulesFuture = _moduleService.getModules();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Configurações'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.videocam), text: 'Câmeras'),
            Tab(icon: Icon(Icons.developer_board), text: 'Módulos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCamerasTab(context),
          _buildModulesTab(context),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _tabController.index == 0
          ? () => _editCamera(null)
          : () => _editModule(null),
      tooltip: _tabController.index == 0
          ? 'Adicionar Nova Câmera'
          : 'Adicionar Novo Módulo',
      child: const Icon(Icons.add),
    );
  }

  // Builder for the Cameras tab
  Widget _buildCamerasTab(BuildContext context) {
    return FutureBuilder<List<Camera>>(
      future: _camerasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Erro ao carregar câmeras: ${snapshot.error}'));
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
                      tooltip: 'Editar Câmera',
                      onPressed: () => _editCamera(camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Remover Câmera',
                      onPressed: () => _deleteCamera(camera.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editCamera(Camera? camera) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraEditScreen(camera: camera)),
    );
    if (result == true) {
      _loadCameras();
    }
  }

  void _deleteCamera(int id) async {
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Câmera removida com sucesso!'),
            backgroundColor: Colors.green),
      );
      _loadCameras();
    }
  }

  // Builder for the Modules tab
  Widget _buildModulesTab(BuildContext context) {
    return FutureBuilder<List<HardwareModule>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Erro ao carregar módulos: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum módulo configurado.'));
        }

        final modules = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: const Icon(Icons.memory),
                title: Text(module.name),
                subtitle: Text(
                    '${module.type.displayName} - ${module.ipAddress}',
                    overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar Módulo',
                      onPressed: () => _editModule(module),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Remover Módulo',
                      onPressed: () => _deleteModule(module.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editModule(HardwareModule? module) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ModuleEditScreen(module: module)),
    );
    if (result == true) {
      _loadModules();
    }
  }

  void _deleteModule(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja remover este módulo?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _moduleService.removeModule(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Módulo removido com sucesso!'),
            backgroundColor: Colors.green),
      );
      _loadModules();
    }
  }
}
