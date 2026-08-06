import 'package:flutter/foundation.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/scan_repository.dart';

class ScanProvider extends ChangeNotifier {
  ScanProvider({ScanRepository? repository})
      : _repository = repository ?? ScanRepository();

  final ScanRepository _repository;

  List<ScanEvent> events = const [];
  ScanCounts counts = const ScanCounts();
  int eligibleCount = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;
  String? lastScanMessage;

  Future<void> loadEvents(String token) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      events = await _repository.getEvents(token);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to load scan events.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetail({
    required String token,
    required ScanEvent event,
  }) async {
    lastScanMessage = null;
    if (event.category == 'Majlis') {
      counts = await _repository.getMajlisCounts(token: token, majlisId: event.id);
    } else if (event.category == 'Sabaq') {
      eligibleCount = await _repository.getSabaqEligibleCount(
        token: token,
        sabaqId: event.id,
      );
    } else if (event.category == 'Asbaq') {
      eligibleCount = await _repository.getAsbaqEligibleCount(
        token: token,
        asbaqId: event.id,
      );
      counts = await _repository.getAsbaqCounts(token: token, asbaqId: event.id);
    }
    notifyListeners();
  }

  Future<bool> submitScan({
    required String token,
    required ScanEvent event,
    required String its,
  }) async {
    isSubmitting = true;
    lastScanMessage = null;
    errorMessage = null;
    notifyListeners();

    try {
      if (event.category == 'Sabaq') {
        lastScanMessage = await _repository.registerSabaq(
          token: token,
          its: its,
          sabaqId: event.id,
        );
      } else if (event.category == 'General') {
        lastScanMessage = await _repository.registerGeneral(
          token: token,
          its: its,
          eventId: event.id,
        );
      } else if (event.category == 'Asbaq') {
        lastScanMessage = await _repository.saveAsbaqScan(
          token: token,
          asbaqId: event.id,
          its: its,
        );
        eligibleCount = await _repository.getAsbaqEligibleCount(
          token: token,
          asbaqId: event.id,
        );
        counts = await _repository.getAsbaqCounts(token: token, asbaqId: event.id);
      } else {
        lastScanMessage = await _repository.saveMajlisScan(
          token: token,
          majlisId: event.id,
          its: its,
        );
        counts = await _repository.getMajlisCounts(token: token, majlisId: event.id);
      }
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      lastScanMessage = e.message;
      return false;
    } catch (_) {
      errorMessage = 'Scan failed. Please try again.';
      lastScanMessage = errorMessage;
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
