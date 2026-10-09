import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_screen.dart';
import 'theme.dart';
import 'water_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The water follows gravity, so the UI itself must not rotate.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    WaterlyApp(onboarded: prefs.getBool(OnboardingScreen.doneKey) ?? false),
  );
}

class WaterlyApp extends StatelessWidget {
  const WaterlyApp({super.key, this.onboarded = true});

  /// False on first launch, which shows the onboarding.
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waterly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.fromSeed(seedColor: WaterColors.bgBottom),
      ),
      home: onboarded ? const WaterScreen() : const OnboardingScreen(),
    );
  }
}
