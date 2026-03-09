import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/daily_steps_service.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = 'https://nrhtkdeyznflvcevagjc.supabase.co';
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: 'sb_publishable_hT9YqLCUeYmMHZ-fuoE0-Q_ZZ_3st-X',
  );
  if (kDebugMode) {
    debugPrint('[Supabase] Project URL (app is using this project): $supabaseUrl');
    DailyStepsService.debugSupabaseUrl = supabaseUrl;
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0B0B0F),
      systemNavigationBarColor: Color(0xFF0B0B0F),
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GotMotionApp());
}

class GotMotionApp extends StatelessWidget {
  const GotMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Got Motion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3B82F6),
          surface: const Color(0xFF0B0B0F),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0B0F),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
