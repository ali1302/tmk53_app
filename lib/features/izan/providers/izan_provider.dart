import 'package:flutter/foundation.dart';

import '../../../core/models/app_models.dart';
import '../../../core/network/api_client.dart';
import '../data/izan_repository.dart';

class IzanEventCard {
  IzanEventCard({
    required this.event,
    this.members = const [],
    this.familyAll = const [],
    this.guests = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  MajlisItem event;
  /// Members shown in UI (HOF-only when event.onlyHof).
  List<IzanMember> members;
  /// Full family list used when saving Only-HOF events.
  List<IzanMember> familyAll;
  List<IzanGuest> guests;
  bool isLoading;
  bool isSaving;
  String? errorMessage;

  String get id => event.id;
}

class IzanProvider extends ChangeNotifier {
  IzanProvider({IzanRepository? repository})
      : _repository = repository ?? IzanRepository();

  final IzanRepository _repository;

  List<IzanEventCard> cards = const [];
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  Future<void> load({
    required String token,
    required String itsId,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final events = await _repository.listActive(token: token, itsId: itsId);
      cards = [
        for (final e in events) IzanEventCard(event: e, isLoading: true),
      ];
      isLoading = false;
      notifyListeners();

      await Future.wait([
        for (final card in cards)
          _loadCardDetail(token: token, itsId: itsId, majlisId: card.id),
      ]);
    } on ApiException catch (e) {
      errorMessage = e.message;
      cards = const [];
    } catch (_) {
      errorMessage = 'Unable to load RSVP events.';
      cards = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCardDetail({
    required String token,
    required String itsId,
    required String majlisId,
  }) async {
    final index = cards.indexWhere((c) => c.id == majlisId);
    if (index < 0) return;

    final updated = List<IzanEventCard>.from(cards);
    updated[index].isLoading = true;
    updated[index].errorMessage = null;
    cards = updated;
    notifyListeners();

    try {
      final detail = await _repository.getUsers(
        token: token,
        itsId: itsId,
        majlisId: majlisId,
      );
      final i = cards.indexWhere((c) => c.id == majlisId);
      if (i < 0) return;
      final next = List<IzanEventCard>.from(cards);
      if (detail.majlis != null && detail.majlis!.title.isNotEmpty) {
        final prev = next[i].event;
        next[i].event = MajlisItem(
          id: detail.majlis!.id.isNotEmpty ? detail.majlis!.id : prev.id,
          title: detail.majlis!.title.isNotEmpty ? detail.majlis!.title : prev.title,
          date: detail.majlis!.date.isNotEmpty ? detail.majlis!.date : prev.date,
          hijriDate: detail.majlis!.hijriDate.isNotEmpty
              ? detail.majlis!.hijriDate
              : prev.hijriDate,
          onlyHof: detail.onlyHof || detail.majlis!.onlyHof || prev.onlyHof,
        );
      } else if (detail.onlyHof) {
        final prev = next[i].event;
        next[i].event = MajlisItem(
          id: prev.id,
          title: prev.title,
          date: prev.date,
          hijriDate: prev.hijriDate,
          onlyHof: true,
        );
      }
      final onlyHof = next[i].event.onlyHof || detail.onlyHof;
      next[i].familyAll = detail.members;
      if (onlyHof) {
        final hofOnly = detail.members.where((m) => m.isHof).toList();
        next[i].members = hofOnly.isNotEmpty
            ? hofOnly
            : (detail.members.isNotEmpty
                ? [detail.members.first]
                : const <IzanMember>[]);
        next[i].guests = const [];
        // Ensure flag stuck on event for UI checks.
        if (!next[i].event.onlyHof) {
          final prev = next[i].event;
          next[i].event = MajlisItem(
            id: prev.id,
            title: prev.title,
            date: prev.date,
            hijriDate: prev.hijriDate,
            onlyHof: true,
          );
        }
      } else {
        next[i].members = detail.members;
        next[i].guests = detail.guests;
      }
      next[i].isLoading = false;
      next[i].errorMessage = null;
      cards = next;
    } on ApiException catch (e) {
      final i = cards.indexWhere((c) => c.id == majlisId);
      if (i < 0) return;
      final next = List<IzanEventCard>.from(cards);
      next[i].isLoading = false;
      next[i].errorMessage = e.message;
      next[i].members = const [];
      next[i].guests = const [];
      cards = next;
    } catch (_) {
      final i = cards.indexWhere((c) => c.id == majlisId);
      if (i < 0) return;
      final next = List<IzanEventCard>.from(cards);
      next[i].isLoading = false;
      next[i].errorMessage = 'Unable to load registration.';
      next[i].members = const [];
      next[i].guests = const [];
      cards = next;
    }
    notifyListeners();
  }

  IzanEventCard? _card(String majlisId) {
    final i = cards.indexWhere((c) => c.id == majlisId);
    return i < 0 ? null : cards[i];
  }

  void toggleMember(String majlisId, String its, bool value) {
    final i = cards.indexWhere((c) => c.id == majlisId);
    if (i < 0) return;
    final next = List<IzanEventCard>.from(cards);
    next[i].members = [
      for (final m in next[i].members)
        if (m.its == its) m.copyWith(registered: value) else m,
    ];
    cards = next;
    successMessage = null;
    notifyListeners();
  }

  void addGuest(String majlisId, IzanGuest guest) {
    final i = cards.indexWhere((c) => c.id == majlisId);
    if (i < 0 || cards[i].event.onlyHof) return;
    final next = List<IzanEventCard>.from(cards);
    next[i].guests = [...next[i].guests, guest];
    cards = next;
    successMessage = null;
    notifyListeners();
  }

  void removeGuest(String majlisId, int index) {
    final i = cards.indexWhere((c) => c.id == majlisId);
    if (i < 0) return;
    final guests = cards[i].guests;
    if (index < 0 || index >= guests.length) return;
    final next = List<IzanEventCard>.from(cards);
    next[i].guests = [
      for (var g = 0; g < guests.length; g++)
        if (g != index) guests[g],
    ];
    cards = next;
    successMessage = null;
    notifyListeners();
  }

  Future<bool> save({
    required String token,
    required String itsId,
    required String majlisId,
  }) async {
    final card = _card(majlisId);
    if (card == null) return false;

    final i = cards.indexWhere((c) => c.id == majlisId);
    final next = List<IzanEventCard>.from(cards);
    next[i].isSaving = true;
    next[i].errorMessage = null;
    cards = next;
    successMessage = null;
    notifyListeners();

    try {
      final onlyHof = card.event.onlyHof;
      final Map<String, bool> selections;
      if (onlyHof) {
        final hofRegistered = card.members.any((m) => m.registered);
        final hofIts = card.members.isNotEmpty ? card.members.first.its : '';
        selections = {
          for (final m in card.familyAll)
            m.its: (m.isHof || m.its == hofIts) && hofRegistered,
        };
      } else {
        selections = {for (final m in card.members) m.its: m.registered};
      }
      final message = await _repository.register(
        token: token,
        itsId: itsId,
        majlisId: majlisId,
        selections: selections,
        guests: onlyHof ? const [] : card.guests,
      );
      successMessage = message;
      await _loadCardDetail(token: token, itsId: itsId, majlisId: majlisId);
      final j = cards.indexWhere((c) => c.id == majlisId);
      if (j >= 0) {
        final after = List<IzanEventCard>.from(cards);
        after[j].isSaving = false;
        cards = after;
      }
      return true;
    } on ApiException catch (e) {
      final j = cards.indexWhere((c) => c.id == majlisId);
      if (j >= 0) {
        final after = List<IzanEventCard>.from(cards);
        after[j].isSaving = false;
        after[j].errorMessage = e.message;
        cards = after;
      }
      return false;
    } catch (_) {
      final j = cards.indexWhere((c) => c.id == majlisId);
      if (j >= 0) {
        final after = List<IzanEventCard>.from(cards);
        after[j].isSaving = false;
        after[j].errorMessage = 'Unable to save registration.';
        cards = after;
      }
      return false;
    } finally {
      notifyListeners();
    }
  }
}
