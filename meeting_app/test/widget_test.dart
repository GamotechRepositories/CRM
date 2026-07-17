import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:meeting_app/app.dart';
import 'package:meeting_app/core/constants/storage_keys.dart';
import 'package:meeting_app/core/storage/hive_service.dart';
import 'package:meeting_app/shared/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HiveService hiveService;
  late Directory tempDir;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    tempDir = Directory.systemTemp.createTempSync('meeting_app_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    if (Hive.isBoxOpen(StorageKeys.settingsBox)) {
      await Hive.box<dynamic>(StorageKeys.settingsBox).clear();
      hiveService = HiveService(Hive.box<dynamic>(StorageKeys.settingsBox));
    } else {
      hiveService = await HiveService.openBox();
    }
  });

  testWidgets('App renders splash then login when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: createAppOverrides(hiveService),
        child: const MeetingApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Executive Meeting'), findsWidgets);

    // Splash duration + auth bootstrap
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Meeting login'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
