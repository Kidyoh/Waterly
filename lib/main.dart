import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'water_screen.dart';

void main() {
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
  runApp(const WaterlyApp());
}

class WaterlyApp extends StatelessWidget {
  const WaterlyApp({super.key});

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
      home: const WaterScreen(),
    );
  }
}
