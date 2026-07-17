import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  final hiveService = await bootstrap();

  runApp(
    ProviderScope(
      overrides: createAppOverrides(hiveService),
      child: const MeetingApp(),
    ),
  );
}
