import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/app_boot.dart';
import 'services/daily_steps_service.dart';
import 'screens/auth_gate.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = 'https://nrhtkdeyznflvcevagjc.supabase.co';
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: 'sb_publishable_hT9YqLCUeYmMHZ-fuoE0-Q_ZZ_3st-X',
  );
  if (kDebugMode) {
    debugPrint(
      '[Supabase] Project URL (app is using this project): $supabaseUrl',
    );
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const _AppBootstrap(),
    );
  }
}

/// Keeps the splash on screen while [AuthGate] resolves the session and any
/// launch deep link, then cross-fades to the app. A floor on the visible
/// duration stops the splash flashing past on a warm start.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  static const _minimumVisible = Duration(milliseconds: 1900);
  static const _fadeOut = Duration(milliseconds: 550);

  bool _splashVisible = true;
  bool _splashMounted = true;

  @override
  void initState() {
    super.initState();
    _runSplash();
  }

  Future<void> _runSplash() async {
    await Future.wait([
      Future<void>.delayed(_minimumVisible),
      AppBoot.whenReady(),
    ]);
    if (!mounted) return;
    setState(() => _splashVisible = false);
    await Future<void>.delayed(_fadeOut);
    if (!mounted) return;
    setState(() => _splashMounted = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AuthGate()),
        if (_splashMounted)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_splashVisible,
              child: AnimatedOpacity(
                opacity: _splashVisible ? 1 : 0,
                duration: _fadeOut,
                curve: Curves.easeOut,
                child: const SplashScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
