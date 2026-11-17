import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'core/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TusAdminApp());
}

class TusAdminApp extends StatelessWidget {
  const TusAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const tusRed = Color(0xFFC62828); // Kräftiges TuS-Rot
    const neutralBg = Color(0xFFF5F6F8); // Neutrales Hellgrau ohne Rosa-Stich
    const darkSlate = Color(0xFF1E242B); // Dunkles Anthrazit für Texte & Akzente

    final baseScheme = ColorScheme.fromSeed(
      seedColor: tusRed,
      brightness: Brightness.light,
    );

    final cleanScheme = baseScheme.copyWith(
      primary: tusRed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFECEFF1), // Neutrales Blaugrau statt Rosa
      onPrimaryContainer: darkSlate,
      secondary: darkSlate,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE2E6EC), // Neutrales Grau für Badges/Chips
      onSecondaryContainer: darkSlate,
      surface: Colors.white,
      onSurface: darkSlate,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: neutralBg,
      surfaceContainerHigh: const Color(0xFFECEFF3),
      surfaceContainerHighest: const Color(0xFFE2E6EC),
      outline: const Color(0xFFCBD2D9),
      outlineVariant: const Color(0xFFE4E7EB),
    );

    return MaterialApp(
      title: 'TuS Neuhofen Handball – Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: cleanScheme,
        scaffoldBackgroundColor: neutralBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSlate,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.white,
          indicatorColor: tusRed.withValues(alpha: 0.12),
          selectedIconTheme: const IconThemeData(color: tusRed),
          selectedLabelTextStyle: const TextStyle(
            color: tusRed,
            fontWeight: FontWeight.w600,
          ),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade700),
          unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade700),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE4E7EB)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: tusRed.withValues(alpha: 0.12),
          checkmarkColor: tusRed,
          side: const BorderSide(color: Color(0xFFCBD2D9)),
          labelStyle: const TextStyle(color: darkSlate),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD2D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD2D9)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}