import 'package:flutter/material.dart';
import '../../models/camera.dart';
import 'camera_stream_tile.dart';
import 'focused_live_view_screen.dart';

class CameraGridPanel extends StatelessWidget {
  final List<Camera> cameras;
  final ValueChanged<Camera> onConfigureCamera;

  const CameraGridPanel({
    super.key,
    required this.cameras,
    required this.onConfigureCamera,
  });

  @override
  Widget build(BuildContext context) {
    // Calcula a proporção para um layout próximo de 16:9
    const double crossAxisSpacing = 8.0;
    const double mainAxisSpacing = 8.0;
    const int crossAxisCount = 3;
    final screenWidth = MediaQuery.of(context).size.width; // Ocupa 100% agora
    final itemWidth = (screenWidth - (crossAxisSpacing * (crossAxisCount + 1))) / crossAxisCount;
    final itemHeight = itemWidth / (16 / 9);
    final childAspectRatio = itemWidth / itemHeight;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(crossAxisSpacing),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: cameras.length,
        itemBuilder: (context, index) {
          final camera = cameras[index];
          return GestureDetector(
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FocusedLiveViewScreen(camera: camera),
                ),
              );
            },
            child: CameraStreamTile(
              key: ValueKey(camera.id),
              camera: camera,
              onConfigure: () => onConfigureCamera(camera),
            ),
          );
        },
      ),
    );
  }
}
