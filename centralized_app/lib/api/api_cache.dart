import 'dart:async';

/// In-memory GET response cache shared by every [ApiClient] instance.
///
/// Keys are full request URLs (base URL + path + query), so entries are
/// naturally scoped to the selected company. Any mutation clears the cache so
/// the next read after a create/update/delete always hits the server.
class ApiCache {
  ApiCache._();

  static const Duration defaultTtl = Duration(minutes: 5);

  static final Map<String, _CacheEntry> _entries = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

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

  static Future<Map<String, dynamic>> getOrFetch(
    String key,
    Future<Map<String, dynamic>> Function() fetch, {
    Duration ttl = defaultTtl,
  }) {
    if (!isFreshRequested) {
      final hit = _entries[key];
      if (hit != null && !hit.isExpired) {
        return Future.value(_clone(hit.data));
      }
      final pending = _inFlight[key];
      if (pending != null) return pending.then(_clone);
    }

    final future = fetch().then((data) {
      _entries[key] = _CacheEntry(data, DateTime.now().add(ttl));
      return data;
    }).whenComplete(() => _inFlight.remove(key));
    _inFlight[key] = future;
    return future.then(_clone);
  }

  static void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> data) =>
      _deepCopy(data) as Map<String, dynamic>;

  static Object? _deepCopy(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): _deepCopy(e.value),
      };
    }
    if (value is List) return value.map(_deepCopy).toList();
    return value;
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.expiresAt);

  final Map<String, dynamic> data;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
