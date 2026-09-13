import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/tv_browser_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile/TV display optimizations (skip on desktop platforms like macOS/Windows/Linux)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  runApp(const EinthusanTvApp());
}

class EinthusanTvApp extends StatelessWidget {
  const EinthusanTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Einthusan TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          surface: Color(0xFF161B22),
        ),
        useMaterial3: true,
      ),
      home: const TvBrowserScreen(),
    );
  }
}
