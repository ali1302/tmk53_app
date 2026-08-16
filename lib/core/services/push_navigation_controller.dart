import 'package:flutter/foundation.dart';

/// Routes push taps into the authenticated shell (e.g. open Broadcast).
class PushNavigationController extends ChangeNotifier {
  PushNavigationController._();
  static final PushNavigationController instance = PushNavigationController._();

  bool _openBroadcast = false;

  bool get shouldOpenBroadcast => _openBroadcast;

  void requestOpenBroadcast() {
    _openBroadcast = true;
    notifyListeners();
  }

  void consumeOpenBroadcast() {
    if (!_openBroadcast) return;
    _openBroadcast = false;
  }
}
