import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_env.dart';
import '../utils/travel_map_helpers.dart';

/// In-dashboard route map — Google Maps embed/Web when possible, OSM fallback.
class TravelRouteMap extends StatefulWidget {
  const TravelRouteMap({
    super.key,
    required this.points,
    this.routeUrl,
    this.height = 280,
    this.emptyMessage = 'No route points yet.',
  });

  final List<Map<String, dynamic>> points;
  final String? routeUrl;
  final double height;
  final String emptyMessage;

  /// Opens the route in the external Google Maps app.
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
  WebViewController? _webController;
  bool _webLoading = true;

  List<TravelMapPoint> get _valid => TravelMapHelpers.validPoints(widget.points);

  String? get _directionsUrl {
    if (widget.routeUrl != null && widget.routeUrl!.trim().isNotEmpty) {
      return widget.routeUrl;
    }
    return TravelMapHelpers.buildGoogleMapsDirectionsUrl(_valid);
  }

  String? get _embedUrl {
    final key = AppEnv.googleMapsApiKey;
    if (key.isEmpty) return null;
    return TravelMapHelpers.buildGoogleMapsEmbedUrl(_valid, key);
  }

  @override
  void didUpdateWidget(covariant TravelRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points || oldWidget.routeUrl != widget.routeUrl) {
      _initWebView();
    }
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // Maps Embed API only works inside an <iframe> — never as a top-level page.
    final embed = _embedUrl;
    if (embed == null || _valid.isEmpty) {
      setState(() {
        _webController = null;
        _webLoading = false;
      });
      return;
    }

    setState(() => _webLoading = true);
    final safeSrc = embed
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #f8fafc; }
    iframe { border: 0; width: 100%; height: 100%; display: block; }
  </style>
</head>
<body>
  <iframe
    src="$safeSrc"
    title="Google Maps travel route"
    loading="lazy"
    referrerpolicy="no-referrer-when-downgrade"
    allowfullscreen
  ></iframe>
</body>
</html>
''';

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8FAFC))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _webLoading = false);
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://localhost/');
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
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      );
    }

    final useGoogleWeb = _webController != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: useGoogleWeb
                ? WebViewWidget(controller: _webController!)
                : _OsmRouteMap(points: _valid),
          ),
          if (useGoogleWeb && _webLoading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF8FAFC),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (_directionsUrl != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: InkWell(
                  onTap: _openInGoogleMaps,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 16, color: Color(0xFF4338CA)),
                        SizedBox(width: 6),
                        Text(
                          'Open in Google Maps',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
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
}

class _OsmRouteMap extends StatelessWidget {
  const _OsmRouteMap({required this.points});

  final List<TravelMapPoint> points;

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final bounds = LatLngBounds.fromPoints(latLngs);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.centralized_app',
        ),
        if (latLngs.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLngs,
                color: const Color(0xFF4F46E5),
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < points.length; i++)
              Marker(
                point: latLngs[i],
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: i == 0 || i == points.length - 1 ? const Color(0xFF0F172A) : const Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    i == 0 ? 'S' : (i == points.length - 1 && points.length > 1 ? 'E' : '$i'),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
