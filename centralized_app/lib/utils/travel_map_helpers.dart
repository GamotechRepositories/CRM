import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Helpers for travel route maps — mirrors web `TravelRouteMap.jsx` / `travelDistance.js`.
class TravelMapHelpers {
  TravelMapHelpers._();

  static List<TravelMapPoint> validPoints(List<Map<String, dynamic>> points) {
    final list = <TravelMapPoint>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final lat = num.tryParse('${p['latitude'] ?? p['lat']}');
      final lng = num.tryParse('${p['longitude'] ?? p['lng'] ?? p['lon']}');
      if (lat == null || lng == null) continue;
      final property = p['property'];
      final propTitle = property is Map ? (property['title'] ?? '').toString() : '';
      list.add(
        TravelMapPoint(
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          label: propTitle.isNotEmpty
              ? propTitle
              : (p['visitorName'] ?? p['address'] ?? 'Stop ${i + 1}').toString(),
          type: (p['type'] ?? 'check_in').toString(),
          address: (p['address'] ?? '').toString(),
        ),
      );
    }
    return list;
  }

  static List<LatLng> extractRouteCoordinates(dynamic raw) {
    if (raw == null) return const [];
    final coords = <LatLng>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is List && item.length >= 2) {
          final lat = num.tryParse('${item[0]}');
          final lng = num.tryParse('${item[1]}');
          if (lat != null && lng != null) {
            coords.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        } else if (item is Map) {
          final lat = num.tryParse('${item['lat'] ?? item['latitude']}');
          final lng = num.tryParse('${item['lng'] ?? item['longitude']}');
          if (lat != null && lng != null) {
            coords.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
    }
    return coords;
  }

  /// Fetches client-side driving route from road network if backend didn't supply full geometry
  static Future<Map<String, dynamic>?> fetchDrivingRoute(List<TravelMapPoint> points) async {
    if (points.length < 2) return null;
    try {
      var sampled = points;
      if (points.length > 25) {
        sampled = [points.first];
        final step = (points.length - 2) / 23;
        for (var i = 1; i <= 23; i++) {
          sampled.add(points[(i * step).round()]);
        }
        sampled.add(points.last);
      }
      final coordStr = sampled.map((p) => '${p.lng},${p.lat}').join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordStr?overview=full&geometries=geojson&steps=true',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final route = (data['routes'] is List && (data['routes'] as List).isNotEmpty)
          ? data['routes'][0]
          : null;
      if (route == null) return null;

      final roadCoords = <LatLng>[];
      final geometryCoords = route['geometry']?['coordinates'];
      if (geometryCoords is List) {
        for (final pair in geometryCoords) {
          if (pair is List && pair.length >= 2) {
            final lng = num.tryParse('${pair[0]}');
            final lat = num.tryParse('${pair[1]}');
            if (lat != null && lng != null) {
              roadCoords.add(LatLng(lat.toDouble(), lng.toDouble()));
            }
          }
        }
      }

      final roadNames = <String>{};
      final legs = route['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is Map && leg['steps'] is List) {
            for (final step in leg['steps']) {
              if (step is Map) {
                final name = (step['name'] ?? '').toString().trim();
                if (name.isNotEmpty && !name.toLowerCase().startsWith('unnamed')) {
                  roadNames.add(name);
                }
              }
            }
          }
        }
      }

      final roadList = roadNames.toList();
      final routeSummary = roadList.isNotEmpty ? roadList.take(3).join(', ') : 'Direct road route';
      final routeUsed = routeSummary.isNotEmpty ? 'Via $routeSummary' : 'Google Maps driving route';
      final distanceMeters = num.tryParse('${route['distance']}') ?? 0;
      final distanceKm = (distanceMeters / 1000).toDouble();

      return {
        'coordinates': roadCoords,
        'routeUsed': routeUsed,
        'routeSummary': routeSummary,
        'distanceKm': distanceKm,
      };
    } catch (_) {
      return null;
    }
  }

  static String? buildGoogleMapsDirectionsUrl(List<TravelMapPoint> points) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      return 'https://www.google.com/maps?q=${points.first.lat},${points.first.lng}';
    }
    final origin = '${points.first.lat},${points.first.lng}';
    final destination = '${points.last.lat},${points.last.lng}';
    final mid = points.length > 2
        ? points.sublist(1, points.length - 1).map((p) => '${p.lat},${p.lng}').join('|')
        : '';
    var url =
        'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}&travelmode=driving';
    if (mid.isNotEmpty) {
      url += '&waypoints=${Uri.encodeComponent(mid)}';
    }
    return url;
  }
}

class TravelMapPoint {
  const TravelMapPoint({
    required this.lat,
    required this.lng,
    required this.label,
    required this.type,
    this.address = '',
  });

  final double lat;
  final double lng;
  final String label;
  final String type;
  final String address;
}
