import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/travel_map_helpers.dart';

/// In-app Google Maps route viewer — renders authentic Google Maps tiles,
/// actual driving road paths, custom Google pins, route HUD and satellite toggle.
class TravelRouteMap extends StatefulWidget {
  const TravelRouteMap({
    super.key,
    required this.points,
    this.routeCoordinates,
    this.routeUrl,
    this.routeUsed,
    this.routeSummary,
    this.totalDistanceKm,
    this.height = 250,
    this.emptyMessage = 'No route points yet. Start journey to track route.',
  });

  final List<Map<String, dynamic>> points;
  final dynamic routeCoordinates;
  final String? routeUrl;
  final String? routeUsed;
  final String? routeSummary;
  final num? totalDistanceKm;
  final double height;
  final String emptyMessage;

  /// Opens the driving route in the official Google Maps application.
  static Future<void> openDirections(
    BuildContext context, {
    String? routeUrl,
    List<Map<String, dynamic>> points = const [],
  }) async {
    final valid = TravelMapHelpers.validPoints(points);
    final url = (routeUrl != null && routeUrl.trim().isNotEmpty)
        ? routeUrl
        : TravelMapHelpers.buildGoogleMapsDirectionsUrl(valid);
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  State<TravelRouteMap> createState() => _TravelRouteMapState();
}

class _TravelRouteMapState extends State<TravelRouteMap> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;
  List<LatLng> _drivingRoute = [];
  String? _resolvedRouteUsed;
  num? _resolvedDistanceKm;
  bool _isFetchingRoute = false;

  List<TravelMapPoint> get _valid => TravelMapHelpers.validPoints(widget.points);

  String? get _directionsUrl {
    if (widget.routeUrl != null && widget.routeUrl!.trim().isNotEmpty) {
      return widget.routeUrl;
    }
    return TravelMapHelpers.buildGoogleMapsDirectionsUrl(_valid);
  }

  @override
  void initState() {
    super.initState();
    _initRouteData();
  }

  @override
  void didUpdateWidget(covariant TravelRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.routeCoordinates != widget.routeCoordinates ||
        oldWidget.routeUsed != widget.routeUsed ||
        oldWidget.totalDistanceKm != widget.totalDistanceKm) {
      _initRouteData();
      _fitBounds();
    }
  }

  void _initRouteData() {
    _resolvedRouteUsed = widget.routeUsed ?? widget.routeSummary;
    _resolvedDistanceKm = widget.totalDistanceKm;

    // 1. Try extracting explicit road coordinates from backend
    final passedCoords = TravelMapHelpers.extractRouteCoordinates(widget.routeCoordinates);
    if (passedCoords.isNotEmpty) {
      setState(() {
        _drivingRoute = passedCoords;
      });
      return;
    }

    // 2. If valid points are 2+, fetch driving road trajectory
    if (_valid.length >= 2) {
      _fetchRoadRoute();
    } else {
      setState(() {
        _drivingRoute = _valid.map((p) => LatLng(p.lat, p.lng)).toList();
      });
    }
  }

  Future<void> _fetchRoadRoute() async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final res = await TravelMapHelpers.fetchDrivingRoute(_valid);
      if (!mounted) return;
      if (res != null) {
        final coords = res['coordinates'] as List<LatLng>? ?? [];
        setState(() {
          if (coords.isNotEmpty) {
            _drivingRoute = coords;
          }
          if (_resolvedRouteUsed == null || _resolvedRouteUsed!.isEmpty) {
            _resolvedRouteUsed = res['routeUsed']?.toString();
          }
          if (_resolvedDistanceKm == null || _resolvedDistanceKm == 0) {
            _resolvedDistanceKm = res['distanceKm'] as num?;
          }
        });
      } else {
        setState(() {
          _drivingRoute = _valid.map((p) => LatLng(p.lat, p.lng)).toList();
        });
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _fitBounds() {
    final pts = _drivingRoute.isNotEmpty
        ? _drivingRoute
        : _valid.map((p) => LatLng(p.lat, p.lng)).toList();
    if (pts.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (pts.length == 1) {
          _mapController.move(pts.first, 15.0);
          return;
        }

        final bounds = LatLngBounds.fromPoints(pts);
        final latSpan = (bounds.north - bounds.south).abs();
        final lngSpan = (bounds.east - bounds.west).abs();

        if (latSpan < 0.0001 && lngSpan < 0.0001) {
          _mapController.move(pts.first, 15.0);
          return;
        }

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
            maxZoom: 16.5,
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> _openInGoogleMaps() async {
    final url = _directionsUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_valid.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 28, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  widget.emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allPoints = _valid.map((p) => LatLng(p.lat, p.lng)).toList();
    final roadPoints = _drivingRoute.isNotEmpty ? _drivingRoute : allPoints;

    LatLng center = allPoints.first;
    double initialZoom = 14.5;
    LatLngBounds? initialBounds;

    if (roadPoints.length > 1) {
      final b = LatLngBounds.fromPoints(roadPoints);
      final latDiff = (b.north - b.south).abs();
      final lngDiff = (b.east - b.west).abs();
      if (latDiff > 0.0001 || lngDiff > 0.0001) {
        initialBounds = b;
      }
    }

    final displayRouteUsed = _resolvedRouteUsed ?? widget.routeUsed ?? widget.routeSummary;
    final displayDistance = _resolvedDistanceKm ?? widget.totalDistanceKm;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: initialZoom,
                initialCameraFit: initialBounds != null
                    ? CameraFit.bounds(
                        bounds: initialBounds,
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
                        maxZoom: 16.5,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                      : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.google.android.apps.maps',
                  maxZoom: 20,
                ),
                if (roadPoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      // Google Maps blue route casing
                      Polyline(
                        points: roadPoints,
                        color: const Color(0xFF1558B0),
                        strokeWidth: 5.5,
                      ),
                      // Core Google Maps driving line
                      Polyline(
                        points: roadPoints,
                        color: const Color(0xFF1A73E8),
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < _valid.length; i++)
                      _buildGoogleMarker(
                        _valid[i],
                        allPoints[i],
                        isStart: i == 0,
                        isEnd: i == _valid.length - 1 && _valid.length > 1,
                        index: i,
                        totalCount: _valid.length,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Top HUD — Route Used & Driving Distance
          if ((displayRouteUsed != null && displayRouteUsed.isNotEmpty) ||
              (displayDistance != null && displayDistance > 0))
            Positioned(
              left: 8,
              top: 8,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation, size: 13, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayRouteUsed != null && displayRouteUsed.isNotEmpty
                            ? displayRouteUsed
                            : 'Driving Route',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (displayDistance != null && displayDistance > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
                        ),
                        child: Text(
                          '${displayDistance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Top-right Satellite Toggle button
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              child: InkWell(
                onTap: () => setState(() => _isSatellite = !_isSatellite),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSatellite ? Icons.map_outlined : Icons.satellite_alt_outlined,
                        size: 13,
                        color: const Color(0xFF1A73E8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isSatellite ? 'Map' : 'Satellite',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Re-center floating button
          Positioned(
            right: 8,
            bottom: 46,
            child: Material(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: InkWell(
                onTap: _fitBounds,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.my_location, size: 16, color: Color(0xFF1A73E8)),
                ),
              ),
            ),
          ),

          // Bottom-left Google Maps watermark
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 2),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'G',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)),
                  ),
                  Text(
                    'o',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEA4335)),
                  ),
                  Text(
                    'o',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFBBC05)),
                  ),
                  Text(
                    'g',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)),
                  ),
                  Text(
                    'l',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF34A853)),
                  ),
                  Text(
                    'e',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEA4335)),
                  ),
                ],
              ),
            ),
          ),

          // Bottom-right Open in Google Maps button
          if (_directionsUrl != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: InkWell(
                  onTap: _openInGoogleMaps,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Google Maps',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildGoogleMarker(
    TravelMapPoint point,
    LatLng latLng, {
    required bool isStart,
    required bool isEnd,
    required int index,
    required int totalCount,
  }) {
    final pinColor = isStart
        ? const Color(0xFF1E8E3E) // Google Maps Start Green
        : isEnd
            ? const Color(0xFFD93025) // Google Maps Destination Red
            : const Color(0xFF1A73E8); // Google Maps Waypoint Blue

    final pinLetter = isStart
        ? 'A'
        : isEnd
            ? (totalCount == 2 ? 'B' : 'E')
            : '$index';

    return Marker(
      point: latLng,
      width: 44,
      height: 48,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: pinColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              pinLetter,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            width: 2,
            height: 5,
            color: pinColor,
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: pinColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
