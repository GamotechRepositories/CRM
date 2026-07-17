import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../organization/domain/organization_constants.dart';
import '../datasources/meeting_local_datasource.dart';
import '../models/meeting_model.dart';
import 'demo_meetings_factory.dart';

/// Seeds portfolio demo meetings once per [OrganizationConstants.meetingsSeedVersion].
class MeetingSeedService {
  MeetingSeedService({
    required HiveService hive,
    required MeetingLocalDataSource local,
  }) : _hive = hive,
       _local = local;

  final HiveService _hive;
  final MeetingLocalDataSource _local;

  Future<void> ensureSeeded() async {
    final version = _hive.get<int>(StorageKeys.meetingsSeedVersion) ?? 0;
    if (version >= OrganizationConstants.meetingsSeedVersion) {
      return;
    }

    final meetings = DemoMeetingsFactory.build(now: DateTime.now());
    await _local.writeAll(meetings.map(MeetingModel.fromEntity).toList());
    await _hive.put(
      StorageKeys.meetingsSeedVersion,
      OrganizationConstants.meetingsSeedVersion,
    );
    AppLogger.info('Demo meetings seeded · ${meetings.length} meetings');
  }
}
