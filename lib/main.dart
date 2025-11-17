import 'dart:async';

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
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/quran_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

const bool _useFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useFirebaseEmulators) {
    await _connectToFirebaseEmulators();
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(MyApp(notificationService: notificationService));
}

Future<void> _connectToFirebaseEmulators() async {
  const host = '127.0.0.1';
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
      child: MaterialApp(
        title: 'Qur\'an Tracker',
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const AuthGate(),
        routes: {
          RegisterScreen.routeName: (_) => const RegisterScreen(),
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

  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: base.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: base.colorScheme.primary,
      foregroundColor: base.colorScheme.onPrimary,
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final userProvider = context.read<UserProvider>();

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
