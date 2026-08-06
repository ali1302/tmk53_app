import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

/// Resolves GPS coordinates and a human-readable place label.
class LocationService {
  Future<DeviceLocation> getCurrentLocation() async {
    await ensureLocationReady();

    Position? position = await Geolocator.getLastKnownPosition();
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getCurrentPosition failed: $e');
      }
      // Fall back to last known if fresh fix timed out.
      position ??= await Geolocator.getLastKnownPosition();
      if (position == null) {
        // One more attempt with Android LocationManager.
        position = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings(forceManager: true),
        );
      }
    }

    final label = await reverseGeocode(position.latitude, position.longitude);
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
    );
  }

  /// Kept for callers that only need the place name.
  Future<String> getCurrentPlaceLabel() async {
    final location = await getCurrentLocation();
    return location.label;
  }

  Future<void> ensureLocationReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError(
        'Location is turned off. Enable GPS/Location and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is blocked. Open app settings and allow Location.',
      );
    }
  }

  LocationSettings _locationSettings({bool forceManager = false}) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: forceManager,
        timeLimit: const Duration(seconds: 25),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 25),
    );
  }

  Future<String> reverseGeocode(double lat, double lon) async {
    try {
      final nominatim = await _reverseNominatim(lat, lon);
      if (nominatim != null && nominatim.isNotEmpty) {
        return nominatim;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Nominatim failed: $e');
      }
    }

    try {
      final bigData = await _reverseBigDataCloud(lat, lon);
      if (bigData != null && bigData.isNotEmpty) {
        return bigData;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BigDataCloud failed: $e');
      }
    }

    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  Future<String?> _reverseNominatim(double lat, double lon) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&lat=$lat&lon=$lon&zoom=10&addressdetails=1',
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'TMKKuwaitApp/1.0 (https://tmk53.com; contact@tmk53.com)',
            'Referer': 'https://tmk53.com/',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final address = decoded['address'];
    if (address is Map) {
      final city = _firstNonEmpty(address, const [
        'city',
        'town',
        'village',
        'municipality',
        'county',
        'suburb',
        'city_district',
      ]);
      final region = _firstNonEmpty(address, const [
        'state',
        'state_district',
        'region',
        'province',
      ]);
      final country = _firstNonEmpty(address, const ['country']);
      final parts = <String>[
        ?city,
        if (region != null && region != city) region,
        ?country,
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }

    final display = decoded['display_name']?.toString().trim();
    if (display != null && display.isNotEmpty) {
      final bits = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      return bits.take(3).join(', ');
    }
    return null;
  }

  Future<String?> _reverseBigDataCloud(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.bigdatacloud.net/data/reverse-geocode-client'
      '?latitude=$lat&longitude=$lon&localityLanguage=en',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final city = _firstNonEmpty(decoded, const [
      'city',
      'locality',
    ]);
    final region = decoded['principalSubdivision']?.toString().trim();
    final country = decoded['countryName']?.toString().trim();

    final parts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (region != null && region.isNotEmpty && region != city) region,
      if (country != null && country.isNotEmpty) country,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? _firstNonEmpty(Map address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null && value is! Map && value is! List) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
