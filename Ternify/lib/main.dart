import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/data_domba_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notifikasi_screen.dart';
import 'main_shell.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();

  await GoogleSignIn.instance.initialize(
    // Jika berjalan di Web, masukkan ID ke clientId. Jika di Android/iOS, biarkan null.
    clientId: kIsWeb
        ? '85092640392-udb6cqaglj2astjt94umt9nhlgapo90l.apps.googleusercontent.com'
        : null,

    // Jika berjalan di Web, serverClientId WAJIB null. Jika di Android/iOS, masukkan ID.
    serverClientId: kIsWeb
        ? null
        : '85092640392-udb6cqaglj2astjt94umt9nhlgapo90l.apps.googleusercontent.com',
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );  runApp(const TernakDigitalApp());
}

class TernakDigitalApp extends StatelessWidget {
  const TernakDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ternify2',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E2D4A)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const MainShell(initialIndex: 0),
        '/riwayat': (context) => const MainShell(initialIndex: 1),
        '/scan': (context) => const MainShell(initialIndex: 2),
        '/kandang': (context) => const MainShell(initialIndex: 3),
        '/profil': (context) => const MainShell(initialIndex: 4),
        '/data-domba': (context) => const DataDombaScreen(),
        '/notifikasi': (context) => const NotifikasiScreen(),
      },
    );
  }
}
