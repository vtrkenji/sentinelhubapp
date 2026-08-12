import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'update/update_screen.dart';
import '../config/app_config.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';
import 'home/camera_grid_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  List<Camera> _cameras = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  static const List<String> _pageTitles = [
    'Painel',
    'Configurações',
  ];

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await _cameraService.getCameras();
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar câmeras: $e')),
        );
      }
    }
  }

  void _reloadCameras() {
    setState(() {
      _isLoading = true;
    });
    _loadCameras();
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 64, color: AppConfig.mutedTextColor),
            const SizedBox(height: 16),
            Text(
              'Nenhuma câmera configurada.',
              style: TextStyle(color: AppConfig.mutedTextColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => const SettingsScreen()))
                    .then((_) => _reloadCameras());
              },
              child: const Text('Abrir Configurações'),
            ),
          ],
        ),
      );
    }

    return CameraGridPanel(cameras: _cameras);
  }

  List<Widget> get _pages => [
        _buildDashboard(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VSGuard OS'),
            Text(
              _pageTitles[_selectedIndex],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppConfig.accentColor,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
        backgroundColor: AppConfig.cardColor.withOpacity(0.95),
        elevation: 0,
        iconTheme: IconThemeData(color: AppConfig.accentColor),
        actionsIconTheme: IconThemeData(color: AppConfig.accentColor),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadCameras,
              tooltip: 'Recarregar Câmeras',
            ),
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Buscar Atualizações',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const UpdateScreen()),
              );
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configurações',
          ),
        ],
      ),
    );
  }
}
