import 'package:flutter/foundation.dart';

class AlertEntry {
  final String title;
  final String body;
  final DateTime time;
  bool read;

  AlertEntry({
    required this.title,
    required this.body,
    DateTime? time,
    this.read = false,
  }) : time = time ?? DateTime.now();
}

class AlertHistoryService extends ChangeNotifier {
  AlertHistoryService._internal();
  static final AlertHistoryService instance = AlertHistoryService._internal();

  final List<AlertEntry> _alerts = [];

  List<AlertEntry> get alerts => List.unmodifiable(_alerts.reversed);

  int get unreadCount => _alerts.where((a) => !a.read).length;

  void addAlert(AlertEntry entry) {
    _alerts.add(entry);
    notifyListeners();
  }

  void markAllRead() {
    for (var a in _alerts) {
      a.read = true;
    }
    notifyListeners();
  }

  void clear() {
    _alerts.clear();
    notifyListeners();
  }
}
