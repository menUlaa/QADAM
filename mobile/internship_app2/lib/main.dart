import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/screens/main_screen.dart';
import 'package:internship_app2/screens/onboarding_screen.dart';
import 'package:internship_app2/screens/role_selection_screen.dart';
import 'package:internship_app2/screens/splash_screen.dart';
import 'package:internship_app2/services/auth_service.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  await initLocale();
  runApp(const QadamApp());
}

class QadamApp extends StatelessWidget {
  const QadamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, _, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, _) => MaterialApp(
          title: 'Qadam',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2164F3),
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              titleTextStyle: GoogleFonts.inter(
                color: const Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              iconTheme: const IconThemeData(color: Color(0xFF374151)),
              actionsIconTheme: const IconThemeData(color: Color(0xFF374151)),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2164F3),
            brightness: Brightness.dark,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: false,
              titleTextStyle: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: AppRoot(),
          builder: (context, child) => child!,
        ),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _authService = AuthService();

  // null = loading, true = logged in, false = not logged in
  bool? _loggedIn;
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      _authService.verifyToken(),
      _checkOnboarding(),
      Future.delayed(const Duration(milliseconds: 1600)), // min splash time
    ]);

    final isValid = results[0] as bool;
    final needsOnboarding = results[1] as bool;

    if (!isValid) await _authService.logout();
    setState(() {
      _loggedIn = isValid;
      _showOnboarding = needsOnboarding;
    });
  }

  Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done') ?? false);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    setState(() => _showOnboarding = false);
  }

  void _login() => setState(() => _loggedIn = true);

  Future<void> _logout() async {
    await _authService.logout();
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    // Still loading
    if (_loggedIn == null || _showOnboarding == null) {
      return const SplashScreen();
    }

    // First launch — show onboarding
    if (_showOnboarding!) {
      return OnboardingScreen(onDone: _finishOnboarding);
    }

    return _loggedIn!
        ? MainScreen(onLogout: _logout)
        : RoleSelectionScreen(onStudentSuccess: _login);
  }
}
