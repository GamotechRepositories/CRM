import 'dart:convert';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../models/meeting_model.dart';

class MeetingLocalDataSource {
  MeetingLocalDataSource(this._hive);

  final HiveService _hive;

  List<MeetingModel> readAll() {
    final raw = _hive.get<String>(StorageKeys.meetings);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MeetingModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> writeAll(List<MeetingModel> meetings) async {
    final encoded = jsonEncode(meetings.map((e) => e.toJson()).toList());
    await _hive.put(StorageKeys.meetings, encoded);
  }

  MeetingModel? readById(String id) {
    try {
      return readAll().firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(MeetingModel meeting) async {
    final all = readAll();
    final index = all.indexWhere((m) => m.id == meeting.id);
    if (index >= 0) {
      all[index] = meeting;
    } else {
      all.add(meeting);
    }
    await writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = readAll()..removeWhere((m) => m.id == id);
    await writeAll(all);
  }
}
