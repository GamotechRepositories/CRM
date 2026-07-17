import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/storage_keys.dart';
import '../error/exceptions.dart';

final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('HiveService must be overridden in ProviderScope');
});

class HiveService {
  HiveService(this._box);

  final Box<dynamic> _box;

  static Future<HiveService> init() async {
    await Hive.initFlutter();
    return openBox();
  }

  static Future<HiveService> openBox() async {
    final box = await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    return HiveService(box);
  }

  T? get<T>(String key) {
    try {
      final value = _box.get(key);
      return value as T?;
    } catch (e) {
      throw CacheException('Failed to read key: $key');
    }
  }

  Future<void> put(String key, dynamic value) async {
    try {
      await _box.put(key, value);
    } catch (e) {
      throw CacheException('Failed to write key: $key');
    }
  }

  Future<void> delete(String key) async {
    try {
      await _box.delete(key);
    } catch (e) {
      throw CacheException('Failed to delete key: $key');
    }
  }

  Future<void> clear() async {
    try {
      await _box.clear();
    } catch (e) {
      throw CacheException('Failed to clear storage');
    }
  }
}
