import 'package:flutter/foundation.dart';

import '../data/contact_us_repository.dart';

class ContactUsProvider extends ChangeNotifier {
  ContactUsProvider({ContactUsRepository? repository})
      : _repository = repository ?? ContactUsRepository();

  final ContactUsRepository _repository;

  ContactUsInfo info = const ContactUsInfo();
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({required String token}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      info = await _repository.fetch(token: token);
      if (!info.hasContent) {
        errorMessage = 'Contact details are not available yet.';
      }
    } catch (e) {
      errorMessage = 'Unable to load Contact Us details.';
      info = const ContactUsInfo();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
