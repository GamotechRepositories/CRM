import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Reverse-geocode helpers — mirrors web `geolocation.js` (Nominatim).
class GeocodeHelpers {
  GeocodeHelpers._();

  static final Map<String, String> _cache = {};
  static final _coordOnlyRe = RegExp(r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$');

  static bool isCoordOnlyAddress(String? address) {
    final trimmed = (address ?? '').trim();
    if (trimmed.isEmpty) return false;
    return _coordOnlyRe.hasMatch(trimmed);
  }

  static String formatCoords(double lat, double lon) =>
      '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

  static String buildAddressFromNominatim(Map<String, dynamic> data) {
    final a = data['address'];
    if (a is! Map) {
      return '${data['display_name'] ?? ''}'.trim();
    }
    final addr = Map<String, dynamic>.from(a);
    final parts = [
      addr['house_number'],
      addr['building'],
      addr['road'] ?? addr['pedestrian'] ?? addr['footway'],
      addr['neighbourhood'] ?? addr['suburb'] ?? addr['quarter'],
      addr['village'] ?? addr['city_district'] ?? addr['district'],
      addr['city'] ?? addr['town'] ?? addr['municipality'],
      addr['state'],
      addr['postcode'],
    ].where((p) => p != null && '$p'.trim().isNotEmpty).map((p) => '$p'.trim()).toList();

    if (parts.isNotEmpty) return parts.join(', ');
    return '${data['display_name'] ?? ''}'.trim();
  }

  static Future<String> resolveAddressFromCoords(double latitude, double longitude) async {
    final key = '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final cached = _cache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude&lon=$longitude&format=json&addressdetails=1&zoom=18',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'MultiCRM-CentralizedApp/1.0',
            },
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode < 200 || res.statusCode >= 300) return '';
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return '';
      final address = buildAddressFromNominatim(Map<String, dynamic>.from(decoded));
      if (address.isNotEmpty) _cache[key] = address;
      return address;
    } catch (_) {
      return '';
    }
  }

  /// Resolve place name from lat/lon, falling back to formatted coords.
  static Future<String> resolveAddressOrCoords(double latitude, double longitude) async {
    final address = await resolveAddressFromCoords(latitude, longitude);
    if (address.isNotEmpty) return address;
    return formatCoords(latitude, longitude);
  }

  /// If [address] is only coordinates, reverse-geocode to a place name.
  static Future<String> resolveDisplayAddress({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final existing = (address ?? '').trim();
    if (existing.isNotEmpty && !isCoordOnlyAddress(existing)) return existing;

    double? lat = latitude;
    double? lon = longitude;
    if ((lat == null || lon == null) && isCoordOnlyAddress(existing)) {
      final parts = existing.split(',');
      if (parts.length == 2) {
        lat ??= double.tryParse(parts[0].trim());
        lon ??= double.tryParse(parts[1].trim());
      }
    }
    if (lat == null || lon == null) return existing;

    final resolved = await resolveAddressFromCoords(lat, lon);
    return resolved.isNotEmpty ? resolved : existing;
  }
}
