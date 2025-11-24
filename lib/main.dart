import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/quran_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/quran_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_isLinuxDesktop) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

const bool _useFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);

bool get _isLinuxDesktop {
  if (kIsWeb) return false;
  try {
    return Platform.isLinux;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only initialize Firebase if not on Linux desktop
  // On Linux, use Firebase emulators if USE_FIREBASE_EMULATORS is set
  if (!_isLinuxDesktop) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      // Continue without Firebase for development
    }
  } else if (_useFirebaseEmulators) {
    // For Linux, try to initialize with emulators
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await _connectToFirebaseEmulators();
    } catch (e) {
      debugPrint('Firebase emulator initialization failed: $e');
      // Continue without Firebase for development
    }
  }

  if (!_isLinuxDesktop || _useFirebaseEmulators) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      debugPrint('Firestore settings failed: $e');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase Messaging setup failed: $e');
    }
  }

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(MyApp(notificationService: notificationService));
}

Future<void> _connectToFirebaseEmulators() async {
  const host = '127.0.0.1';
  try {
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        host: '$host:8080',
        sslEnabled: false,
        persistenceEnabled: false,
      );
    } else {
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  } catch (e) {
    debugPrint('Failed to connect to Firebase emulators: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<QuranService>(create: (_) => QuranService()),
        ChangeNotifierProxyProvider<QuranService, QuranProvider>(
          create: (context) =>
              QuranProvider(service: context.read<QuranService>()),
          update: (_, service, previous) =>
              (previous?..updateService(service)) ??
              QuranProvider(service: service),
        ),
        Provider<QuranService>(create: (_) => QuranService()),
        ChangeNotifierProxyProvider<QuranService, QuranProvider>(
          create: (context) => QuranProvider(service: context.read<QuranService>()),
          update: (_, service, previous) =>
              (previous?..updateService(service)) ?? QuranProvider(service: service),
        ),
        ChangeNotifierProxyProvider2<
          AuthService,
          FirestoreService,
          UserProvider
        >(
          create: (_) => UserProvider(notificationService: notificationService),
          update: (_, auth, firestore, previous) =>
              (previous ??
                    UserProvider(notificationService: notificationService))
                ..updateDependencies(
                  authService: auth,
                  firestoreService: firestore,
                ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Qur\'an Tracker',
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const AuthGate(),
            routes: {
              RegisterScreen.routeName: (_) => const RegisterScreen(),
            },
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
    ),
    useMaterial3: true,
  );

  final scaffoldBg = brightness == Brightness.dark 
      ? const Color(0xFF121212)
      : const Color(0xFFFAFAFA);
  final textColor = brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A1A);
  final secondaryTextColor = brightness == Brightness.dark
      ? Colors.white70
      : const Color(0xFF666666);

  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textColor,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: textColor,
      displayColor: textColor,
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.dark 
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: brightness == Brightness.dark ? 2 : 1,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: base.colorScheme.primary,
      foregroundColor: base.colorScheme.onPrimary,
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userProvider = context.read<UserProvider>();

    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return VerifyEmailScreen(
            onEmailVerified: () {
              userProvider.refreshUser();
            },
          );
        }

        scheduleMicrotask(() {
          userProvider.setFirebaseUser(user);
        });

        return const HomeScreen();
      },
    );
  }
}
