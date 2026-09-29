import 'dart:async';

/// In-memory GET response cache shared by every [ApiClient] instance.
///
/// Stores raw response bodies keyed by full request URL (base URL + path +
/// query), so entries are naturally scoped to the selected company and each
/// caller decodes its own copy. Any mutation clears the cache so the next read
/// after a create/update/delete always hits the server.
class ApiCache {
  ApiCache._();

  static const Duration defaultTtl = Duration(minutes: 5);

  static final Map<String, _CacheEntry> _entries = {};
  static final Map<String, Future<String>> _inFlight = {};

  static const Object _freshZoneKey = #apiCacheFresh;

  /// Paths whose data changes too often to serve from cache.
  static final List<RegExp> _uncachedPaths = [
    RegExp(r'/chat'),
  ];

  static bool isCacheable(String path) =>
      !_uncachedPaths.any((re) => re.hasMatch(path));

  /// True when running inside [fresh] — reads skip the cache.
  static bool get isFreshRequested => Zone.current[_freshZoneKey] == true;

  /// Runs [action] with the cache bypassed (use for pull-to-refresh).
  static Future<T> fresh<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_freshZoneKey: true});

  static Future<String> getOrFetch(
    String key,
    Future<String> Function() fetch, {
    Duration ttl = defaultTtl,
  }) {
    if (!isFreshRequested) {
      final hit = _entries[key];
      if (hit != null && !hit.isExpired) return Future.value(hit.body);
    }
    // Share an in-flight request for the same URL (fresh or not) instead of
    // firing a duplicate.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = fetch().then((body) {
      _entries[key] = _CacheEntry(body, DateTime.now().add(ttl));
      return body;
    });
    _inFlight[key] = future;
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return future;
  }

  static void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}

class _CacheEntry {
  _CacheEntry(this.body, this.expiresAt);

  final String body;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
