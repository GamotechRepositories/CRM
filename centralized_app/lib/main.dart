import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'auth/auth_session.dart';
import 'config/app_env.dart';
import 'screens/app_home.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final session = AuthSession();
  await session.bootstrap();
  runApp(CentralizedApp(session: session));
}

class CentralizedApp extends StatelessWidget {
  const CentralizedApp({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        title: AppEnv.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.light,
          ),
          textTheme: ThemeData(useMaterial3: true).textTheme.apply(
                bodyColor: const Color(0xFF0F172A),
                displayColor: const Color(0xFF0F172A),
              ),
        ),
        home: session.isLoggedIn ? const AppHome() : const LoginScreen(),
      ),
    );
  }
}
