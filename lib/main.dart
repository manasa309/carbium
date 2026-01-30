import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/book_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBcUm9DpRjSXN7l9yHlz-kTpEJoaMpNFi8",
        appId: "1:278319014168:android:97a16f5b1cd5d766b67e6d",
        messagingSenderId: "278319014168",
        projectId: "carbium-3c2d4",
        storageBucket: "carbium-3c2d4.firebasestorage.app",
      ),
    );
    debugPrint("Firebase initialized successfully with explicit options");
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(const CarbiumApp());
}

class CarbiumApp extends StatelessWidget {
  const CarbiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BookProvider>(
          create: (_) => BookProvider(),
          update: (_, auth, bookProvider) => bookProvider!..update(auth),
        ),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          return MaterialApp(
            title: 'Carbium',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: settings.themeMode,
            home: auth.isAuthenticated ? const HomeScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
