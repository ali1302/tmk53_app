import 'dart:convert';

/// Extracts an 8-digit ITS from TMK QR payloads.
///
/// Official member QR encodes JSON: `{"its":"12345678","sabeel":"..."}`.
/// Also accepts plain ITS digits or any text containing an 8-digit ITS.
String? itsFromQrPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      final its = '${decoded['its'] ?? decoded['ejamaat_id'] ?? ''}'.trim();
      final digits = its.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 8) return digits;
      if (digits.length > 8) return digits.substring(0, 8);
    }
  } catch (_) {}

  final onlyDigits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (onlyDigits.length == 8) return onlyDigits;

  final match = RegExp(r'(?<!\d)\d{8}(?!\d)').firstMatch(trimmed);
  if (match != null) return match.group(0);

  if (onlyDigits.length > 8) return onlyDigits.substring(0, 8);
  return null;
}
