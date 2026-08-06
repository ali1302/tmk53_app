import 'package:flutter/foundation.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/home_repository.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({HomeRepository? repository})
      : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;

  HomeDetails? details;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({
    required String token,
    required String itsId,
    bool preview = false,
  }) async {
    if (preview) {
      details = null;
      errorMessage = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      details = await _repository.getHomeDetails(token: token, itsId: itsId);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to load home details.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
