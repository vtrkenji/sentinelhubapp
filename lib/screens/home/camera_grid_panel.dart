import 'package:flutter/material.dart';
import '../../models/camera.dart';
import 'camera_stream_tile.dart';
import 'focused_live_view_screen.dart';

class CameraGridPanel extends StatelessWidget {
  final List<Camera> cameras;

  const CameraGridPanel({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    const double crossAxisSpacing = 8.0;
    const double mainAxisSpacing = 8.0;
    final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 2 : 1;
    const double childAspectRatio = 16 / 9;

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
            ),
          );
        },
      ),
    );
  }
}
