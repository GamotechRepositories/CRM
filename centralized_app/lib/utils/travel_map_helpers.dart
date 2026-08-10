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
        ),
      );
    }
    return list;
  }

  static String? buildGoogleMapsEmbedUrl(List<TravelMapPoint> points, String apiKey) {
    if (apiKey.trim().isEmpty || points.isEmpty) return null;
    if (points.length == 1) {
      final p = points.first;
      return 'https://www.google.com/maps/embed/v1/place?key=${Uri.encodeComponent(apiKey)}&q=${p.lat},${p.lng}&zoom=14';
    }
    final origin = '${points.first.lat},${points.first.lng}';
    final destination = '${points.last.lat},${points.last.lng}';
    final mid = points.length > 2 ? points.sublist(1, points.length - 1).take(10) : <TravelMapPoint>[];
    final waypoints = mid.map((p) => '${p.lat},${p.lng}').join('|');
    var url =
        'https://www.google.com/maps/embed/v1/directions?key=${Uri.encodeComponent(apiKey)}&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}&mode=driving';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=${Uri.encodeComponent(waypoints)}';
    }
    return url;
  }

  static String? buildGoogleMapsDirectionsUrl(List<TravelMapPoint> points) {
    if (points.isEmpty) return null;
    if (points.length == 1) {
      return 'https://www.google.com/maps?q=${points.first.lat},${points.first.lng}';
    }
    final origin = '${points.first.lat},${points.first.lng}';
    final destination = '${points.last.lat},${points.last.lng}';
    final waypoints = points.length > 2
        ? points.sublist(1, points.length - 1).map((p) => '${p.lat},${p.lng}').join('|')
        : '';
    var url =
        'https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}&travelmode=driving';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=${Uri.encodeComponent(waypoints)}';
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
  });

  final double lat;
  final double lng;
  final String label;
  final String type;
}
