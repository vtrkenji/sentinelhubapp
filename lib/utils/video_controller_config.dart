import 'dart:io' show Platform;

import 'package:media_kit_video/media_kit_video.dart';

VideoControllerConfiguration getVideoControllerConfiguration() {
  if (Platform.isAndroid) {
    return const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      vo: 'gpu',
      androidAttachSurfaceAfterVideoParameters: true,
      scale: 1.0,
    );
  }

  return const VideoControllerConfiguration(
    enableHardwareAcceleration: false,
    hwdec: 'no',
    vo: 'libmpv',
    scale: 1.0,
  );
}
