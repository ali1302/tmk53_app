import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/broadcast_repository.dart';

class BroadcastProvider extends ChangeNotifier {
  BroadcastProvider({BroadcastRepository? repository})
      : _repository = repository ?? BroadcastRepository() {
    bootstrapReadIds();
  }

  static const _readIdsKey = 'tmk_broadcast_read_ids';

  final BroadcastRepository _repository;

  List<BroadcastItem> items = const [];
  final Set<String> _readIds = <String>{};
  bool isLoading = false;
  bool readIdsReady = false;
  String? errorMessage;

  Future<void> bootstrapReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_readIdsKey) ?? const <String>[];
      _readIds
        ..clear()
        ..addAll(stored.where((id) => id.trim().isNotEmpty));
    } catch (_) {
      // Keep empty set on failure.
    } finally {
      readIdsReady = true;
      notifyListeners();
    }
  }

  bool isRead(String id) {
    final key = id.trim();
    if (key.isEmpty) return false;
    return _readIds.contains(key);
  }

  Future<void> markRead(String id) async {
    final key = id.trim();
    if (key.isEmpty || _readIds.contains(key)) return;
    _readIds.add(key);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readIdsKey, _readIds.toList());
    } catch (_) {
      // Ignore persistence errors; UI already updated.
    }
  }

  Future<void> load(String itsId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      items = await _repository.list(itsId);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to load broadcasts.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
