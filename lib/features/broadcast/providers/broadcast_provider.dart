import 'package:flutter/foundation.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/broadcast_repository.dart';

class BroadcastProvider extends ChangeNotifier {
  BroadcastProvider({BroadcastRepository? repository})
      : _repository = repository ?? BroadcastRepository();

  final BroadcastRepository _repository;

  List<BroadcastItem> items = const [];
  bool isLoading = false;
  String? errorMessage;

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
