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
  List<ScannedUser> scannedUsers = const [];
  int eligibleCount = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isRemoving = false;
  String? errorMessage;
  String? lastScanMessage;
  String? lastScannedName;
  String? lastScannedIts;
  bool lastScanAlreadyScanned = false;

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
    lastScannedName = null;
    lastScannedIts = null;
    lastScanAlreadyScanned = false;
    try {
      if (event.category == 'Majlis') {
        counts = await _repository.getMajlisCounts(token: token, majlisId: event.id);
        scannedUsers = await _repository.getScannedUsersByUser(token: token, event: event);
      } else if (event.category == 'Sabaq') {
        eligibleCount = await _repository.getSabaqEligibleCount(
          token: token,
          sabaqId: event.id,
        );
        scannedUsers = const [];
      } else if (event.category == 'Asbaq') {
        eligibleCount = await _repository.getAsbaqEligibleCount(
          token: token,
          asbaqId: event.id,
        );
        counts = await _repository.getAsbaqCounts(token: token, asbaqId: event.id);
        scannedUsers = await _repository.getScannedUsersByUser(token: token, event: event);
      } else {
        scannedUsers = const [];
      }
    } catch (_) {
      // Keep prior list if refresh fails.
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
    lastScannedName = null;
    lastScannedIts = null;
    lastScanAlreadyScanned = false;
    errorMessage = null;
    notifyListeners();

    try {
      late final ScanSubmitResult result;
      List<ScannedUser> refreshed = const [];

      if (event.category == 'Sabaq') {
        result = await _repository.registerSabaq(
          token: token,
          its: its,
          sabaqId: event.id,
        );
      } else if (event.category == 'General') {
        result = await _repository.registerGeneral(
          token: token,
          its: its,
          eventId: event.id,
        );
      } else if (event.category == 'Asbaq') {
        result = await _repository.saveAsbaqScan(
          token: token,
          asbaqId: event.id,
          its: its,
        );
        eligibleCount = await _repository.getAsbaqEligibleCount(
          token: token,
          asbaqId: event.id,
        );
        counts = await _repository.getAsbaqCounts(token: token, asbaqId: event.id);
        refreshed = await _repository.getScannedUsersByUser(token: token, event: event);
      } else {
        result = await _repository.saveMajlisScan(
          token: token,
          majlisId: event.id,
          its: its,
        );
        counts = await _repository.getMajlisCounts(token: token, majlisId: event.id);
        refreshed = await _repository.getScannedUsersByUser(token: token, event: event);
      }

      lastScanMessage = result.alreadyScanned
          ? (result.message.trim().isEmpty
              ? 'ITS is already scanned.'
              : result.message)
          : result.message;
      lastScannedIts = its;
      final previous = List<ScannedUser>.from(scannedUsers);
      final wasAlreadyLocal = previous.any((u) => u.its == its);
      lastScanAlreadyScanned = result.alreadyScanned || wasAlreadyLocal;
      if (lastScanAlreadyScanned &&
          (lastScanMessage == null ||
              lastScanMessage == 'Scanned successfully.' ||
              lastScanMessage!.trim().isEmpty)) {
        lastScanMessage = 'ITS is already scanned.';
      }

      if (event.category == 'Sabaq' || event.category == 'General') {
        scannedUsers = _upsertLatest(
          previous: previous,
          refreshed: const [],
          its: its,
          submitName: result.name,
          message: lastScanMessage ?? result.message,
          submitKind: result.kind,
          submitStatusLabel: result.statusLabel,
        );
      } else {
        scannedUsers = _upsertLatest(
          previous: previous,
          refreshed: refreshed,
          its: its,
          submitName: result.name,
          message: lastScanMessage ?? result.message,
          submitKind: result.kind,
          submitStatusLabel: result.statusLabel,
        );
      }

      ScannedUser? latest;
      for (final u in scannedUsers) {
        if (u.its == its) {
          latest = u;
          break;
        }
      }
      lastScannedName = latest?.displayName ?? _pickName(result.name, '', '');

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

  Future<bool> removeScannedUser({
    required String token,
    required ScanEvent event,
    required String its,
  }) async {
    if (isRemoving || isSubmitting) return false;
    isRemoving = true;
    errorMessage = null;
    notifyListeners();

    final previous = List<ScannedUser>.from(scannedUsers);
    try {
      lastScanMessage = await _repository.removeScan(
        token: token,
        event: event,
        its: its,
      );

      // Only update UI after server confirms, then re-sync from server.
      if (event.category == 'Majlis') {
        counts = await _repository.getMajlisCounts(token: token, majlisId: event.id);
        scannedUsers = await _repository.getScannedUsersByUser(token: token, event: event);
      } else if (event.category == 'Asbaq') {
        eligibleCount = await _repository.getAsbaqEligibleCount(
          token: token,
          asbaqId: event.id,
        );
        counts = await _repository.getAsbaqCounts(token: token, asbaqId: event.id);
        scannedUsers = await _repository.getScannedUsersByUser(token: token, event: event);
      } else {
        scannedUsers = previous.where((u) => u.its != its).toList();
      }

      if (scannedUsers.any((u) => u.its == its)) {
        scannedUsers = previous;
        errorMessage = 'Server still has this ITS. Remove failed.';
        lastScanMessage = errorMessage;
        return false;
      }

      return true;
    } on ApiException catch (e) {
      scannedUsers = previous;
      errorMessage = e.message;
      lastScanMessage = e.message;
      return false;
    } catch (_) {
      scannedUsers = previous;
      errorMessage = 'Unable to remove scan.';
      lastScanMessage = errorMessage;
      return false;
    } finally {
      isRemoving = false;
      notifyListeners();
    }
  }

  /// Prefer a real name over empty / Mehman fallbacks.
  String _pickName(String submit, String list, String previous) {
    bool useful(String n) {
      final t = n.trim();
      return t.isNotEmpty && t.toLowerCase() != 'mehman';
    }

    if (useful(submit)) return submit.trim();
    if (useful(list)) return list.trim();
    if (useful(previous)) return previous.trim();
    if (list.trim().isNotEmpty) return list.trim();
    if (submit.trim().isNotEmpty) return submit.trim();
    if (previous.trim().isNotEmpty) return previous.trim();
    return 'Mehman';
  }

  List<ScannedUser> _upsertLatest({
    required List<ScannedUser> previous,
    required List<ScannedUser> refreshed,
    required String its,
    required String submitName,
    required String message,
    ScanUserKind submitKind = ScanUserKind.registered,
    String submitStatusLabel = '',
  }) {
    final prevByIts = {for (final u in previous) u.its: u};
    final refreshByIts = {for (final u in refreshed) u.its: u};
    final allIts = <String>{
      ...refreshByIts.keys,
      ...prevByIts.keys,
      its,
    };

    final merged = <ScannedUser>[];
    for (final id in allIts) {
      final fromRefresh = refreshByIts[id];
      final fromPrev = prevByIts[id];
      final isLatest = id == its;
      final name = _pickName(
        isLatest ? submitName : '',
        fromRefresh?.name ?? '',
        fromPrev?.name ?? '',
      );
      final at = isLatest
          ? DateTime.now()
          : (fromPrev?.at ?? fromRefresh?.at);
      final kind = isLatest
          ? (fromRefresh?.kind ?? submitKind)
          : (fromRefresh?.kind ?? fromPrev?.kind ?? ScanUserKind.registered);
      final statusLabel = isLatest
          ? ((fromRefresh?.statusLabel.isNotEmpty ?? false)
              ? fromRefresh!.statusLabel
              : submitStatusLabel)
          : (fromRefresh?.statusLabel ?? fromPrev?.statusLabel ?? '');
      merged.add(
        ScannedUser(
          its: id,
          name: name,
          message: isLatest ? message : (fromPrev?.message ?? fromRefresh?.message ?? ''),
          at: at,
          kind: kind,
          statusLabel: statusLabel,
        ),
      );
    }

    merged.sort((a, b) {
      if (a.its == its) return -1;
      if (b.its == its) return 1;
      final aAt = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return merged;
  }
}
