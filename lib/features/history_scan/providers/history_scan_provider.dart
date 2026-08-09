import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/history_repository.dart';

class HistoryScanProvider extends ChangeNotifier {
  HistoryScanProvider({HistoryRepository? repository})
      : _repository = repository ?? HistoryRepository();

  final HistoryRepository _repository;

  List<HistoryItem> majlisItems = const [];
  List<HistoryItem> asbaqItems = const [];
  bool isLoadingMajlis = false;
  bool isLoadingAsbaq = false;
  String? majlisError;
  String? asbaqError;

  Future<void> loadAll(String token) async {
    await Future.wait([
      loadMajlis(token),
      loadAsbaq(token),
    ]);
  }

  Future<void> loadMajlis(String token) async {
    isLoadingMajlis = true;
    majlisError = null;
    notifyListeners();
    try {
      majlisItems = await _repository.fetchMajlisHistory(token);
    } on ApiException catch (e) {
      majlisError = e.message;
      majlisItems = const [];
    } catch (_) {
      majlisError = 'Unable to load Miqaat scan history.';
      majlisItems = const [];
    } finally {
      isLoadingMajlis = false;
      notifyListeners();
    }
  }

  Future<void> loadAsbaq(String token) async {
    isLoadingAsbaq = true;
    asbaqError = null;
    notifyListeners();
    try {
      asbaqItems = await _repository.fetchAsbaqHistory(token);
    } on ApiException catch (e) {
      asbaqError = e.message;
      asbaqItems = const [];
    } catch (_) {
      asbaqError = 'Unable to load Sabaq scan history.';
      asbaqItems = const [];
    } finally {
      isLoadingAsbaq = false;
      notifyListeners();
    }
  }
}
