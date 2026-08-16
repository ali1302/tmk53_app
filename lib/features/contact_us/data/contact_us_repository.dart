import '../../../core/network/api_client.dart';

class ContactUsInfo {
  const ContactUsInfo({
    this.title = 'Contact Us',
    this.email = '',
    this.website = '',
    this.address = '',
    this.mapLink = '',
    this.phones = const [],
    this.mobiles = const [],
  });

  final String title;
  final String email;
  final String website;
  final String address;
  final String mapLink;
  final List<String> phones;
  final List<String> mobiles;

  bool get hasContent =>
      email.trim().isNotEmpty ||
      website.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      mapLink.trim().isNotEmpty ||
      phones.isNotEmpty ||
      mobiles.isNotEmpty;

  factory ContactUsInfo.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    var phones = asStringList(json['phones']);
    var mobiles = asStringList(json['mobiles']);

    // Fallback for older API shape: contacts: [{phone, type?}]
    if (phones.isEmpty && mobiles.isEmpty) {
      final contacts = json['contacts'];
      if (contacts is List) {
        for (final item in contacts) {
          if (item is! Map) continue;
          final phone = '${item['phone'] ?? ''}'.trim();
          if (phone.isEmpty) continue;
          final type = '${item['type'] ?? 'phone'}'.toLowerCase();
          if (type == 'mobile') {
            mobiles = [...mobiles, phone];
          } else {
            phones = [...phones, phone];
          }
        }
      }
    }

    return ContactUsInfo(
      title: '${json['title'] ?? 'Contact Us'}'.trim().isEmpty
          ? 'Contact Us'
          : '${json['title'] ?? 'Contact Us'}'.trim(),
      email: '${json['email'] ?? json['contact_email'] ?? ''}'.trim(),
      website: '${json['website'] ?? ''}'.trim(),
      address: '${json['address'] ?? ''}'.trim(),
      mapLink: '${json['maplink'] ?? json['mapLink'] ?? ''}'.trim(),
      phones: phones,
      mobiles: mobiles,
    );
  }
}

class ContactUsRepository {
  ContactUsRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<ContactUsInfo> fetch({required String token}) async {
    final response = await _api.get(
      'Settings/get_contacts',
      token: token,
    );
    if (response is Map<String, dynamic>) {
      // ApiResponseHelper may wrap under data, or return flat.
      final map = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      return ContactUsInfo.fromJson(map);
    }
    return const ContactUsInfo();
  }
}
