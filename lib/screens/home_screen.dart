import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';
import '../models/camera.dart';
import '../services/alert_history_service.dart';
import '../services/camera_service.dart';
import 'home/camera_stream_tile.dart';
import 'modules_and_cameras_screen.dart';
import 'update_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Camera>> _camerasFuture;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  void _loadCameras() {
    setState(() {
      _camerasFuture = CameraService().getCameras();
    });
  }

  Future<void> _openModules({int initialTab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModulesAndCamerasScreen(initialTabIndex: initialTab),
      ),
    );
    _loadCameras();
  }

  Widget _headerAction(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppConfig.accentColor),
      label: Text(
        label,
        style: const TextStyle(
          color: AppConfig.textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        minimumSize: const Size(0, 52),
      ),
    );
  }

  void _openAlertLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedBuilder(
          animation: AlertHistoryService.instance,
          builder: (context, _) {
            final alerts = AlertHistoryService.instance.alerts;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1419),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: AppConfig.accentColor),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Log de notificações',
                          style: TextStyle(
                            color: AppConfig.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppConfig.textColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (alerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18.0),
                      child: Text(
                        'Nenhuma notificação registrada ainda.',
                        style: TextStyle(color: AppConfig.mutedTextColor),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF1D2A31)),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded, color: AppConfig.alertColor),
                            title: Text(
                              alert.title,
                              style: const TextStyle(
                                color: AppConfig.textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${alert.body}\n${alert.time.toLocal().toString().substring(0, 16)}',
                              style: const TextStyle(color: AppConfig.mutedTextColor),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF090E13),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SvgPicture.asset(
            'assets/logo/sentinelhub_logo.svg',
            width: 280,
            height: 46,
            semanticsLabel: 'kTsentinel logo',
          ),
        ),
        actions: [
          const SizedBox(width: 10),
          _headerAction(Icons.videocam_rounded, 'Módulos e câmeras', () => _openModules(initialTab: 0)),
          _headerAction(Icons.memory_rounded, 'Config. ESP32', () => _openModules(initialTab: 1)),
          _headerAction(Icons.system_update_alt_rounded, 'Atualizações', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UpdateScreen()),
            );
          }),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: AlertHistoryService.instance,
            builder: (context, _) {
              final count = AlertHistoryService.instance.unreadCount;
              return IconButton(
                onPressed: _openAlertLog,
                tooltip: 'Log de notificações',
                iconSize: 26,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_rounded, color: AppConfig.accentColor),
                    if (count > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: const BoxDecoration(
                            color: AppConfig.alertColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                child: Text(
                  'Monitoramento',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppConfig.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 18.0),
                child: Text(
                  '${DateTime.now().day.toString().padLeft(2, '0')} ${_monthName(DateTime.now().month)} ${DateTime.now().year} / ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppConfig.mutedTextColor,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: AlertHistoryService.instance,
                builder: (context, _) {
                  final alerts = AlertHistoryService.instance.alerts;
                  if (alerts.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111F22),
                      border: Border.all(color: const Color(0xFF294147)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppConfig.alertColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alerts.first.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppConfig.textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          alerts.first.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppConfig.mutedTextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: FutureBuilder<List<Camera>>(
                  future: _camerasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cameras = (snapshot.data ?? const <Camera>[]).where((camera) => camera.isActive).toList();

                    if (cameras.isEmpty) {
                      return Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101C20),
                            border: Border.all(color: const Color(0xFF1E2E32)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: AppConfig.accentColor.withAlpha(20),
                                  border: Border.all(color: AppConfig.accentColor.withAlpha(120)),
                                ),
                                child: const Icon(
                                  Icons.videocam_off_rounded,
                                  color: AppConfig.accentColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Nenhuma câmera cadastrada',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppConfig.textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Cadastre câmeras ou módulos para começar o monitoramento.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppConfig.mutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () => _openModules(initialTab: 0),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Cadastrar câmeras'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final width = MediaQuery.of(context).size.width;
                    final crossAxisCount = width < 600 ? 1 : (width < 1100 ? 2 : 3);

                    return GridView.builder(
                      itemCount: cameras.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.55,
                      ),
                      itemBuilder: (context, index) {
                        final camera = cameras[index];

                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: CameraStreamTile(camera: camera),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];
    return months[month - 1];
  }
}
