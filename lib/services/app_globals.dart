import 'package:flutter/material.dart';

// Global navigator and scaffold keys used across the app (keeps them out of main.dart
// so services can import without circular dependencies).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
