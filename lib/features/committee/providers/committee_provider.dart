import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/committee_repository.dart';

class CommitteeProvider extends ChangeNotifier {
  CommitteeProvider({CommitteeRepository? repository})
      : _repository = repository ?? CommitteeRepository();

  final CommitteeRepository _repository;

  List<CommitteeMember> members = const [];
  bool isLoading = false;
  String? errorMessage;
  String title =
      'Jamaat Committee Members of TAHERI MOHALLA (KHAITAN-KUWAIT), Kuwait';

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      members = await _repository.fetchMembers();
      if (members.isEmpty) {
        errorMessage = 'No committee members found.';
      }
    } on ApiException catch (e) {
      errorMessage = e.message;
      members = const [];
    } catch (_) {
      errorMessage = 'Unable to load committee members.';
      members = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
