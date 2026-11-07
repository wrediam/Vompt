import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'showcase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Showcase.init();
  if (Showcase.scene != null) await Showcase.seed();

  // Set system UI to dark immediately
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF16161D),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF16161D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const VomptApp());
}
