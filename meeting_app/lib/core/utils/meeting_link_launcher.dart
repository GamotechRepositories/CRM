import 'package:url_launcher/url_launcher.dart';

/// Opens Google Meet / Zoom / browser video links reliably.
abstract final class MeetingLinkLauncher {
  /// Returns a launchable https URI, or null if [raw] is empty/invalid.
  static Uri? normalize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    var candidate = trimmed;
    if (!candidate.contains('://')) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  /// Opens [raw] in an external browser / Meet app.
  /// Returns true if the OS accepted the launch.
  static Future<bool> open(String? raw) async {
    final uri = normalize(raw);
    if (uri == null) return false;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;

      // Fallback: in-app / platform default
      return launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
