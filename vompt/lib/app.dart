import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/documents/providers/documents_provider.dart';
import 'features/documents/screens/document_list_screen.dart';
import 'features/editor/providers/editor_provider.dart';
import 'features/remote/providers/server_provider.dart';
import 'features/remote/remote_coordinator.dart';
import 'features/teleprompter/providers/intelligent_teleprompter_provider.dart';
import 'services/remote_control_service.dart';
import 'showcase.dart';

class VomptApp extends StatefulWidget {
  const VomptApp({super.key});

  @override
  State<VomptApp> createState() => _VomptAppState();
}

class _VomptAppState extends State<VomptApp> {
  bool _sentScreenSize = false;

  @override
  void initState() {
    super.initState();
    RemoteCoordinator.instance.start();
  }

  /// The web remote previews the prompter at the phone's landscape size.
  void _sendScreenSize(BuildContext context) {
    if (_sentScreenSize) return;
    _sentScreenSize = true;
    final size = MediaQuery.of(context).size;
    RemoteControlService().updateTeleprompterState(
      -1,
      false,
      screenWidth: size.longestSide,
      screenHeight: size.shortestSide,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(create: (_) => EditorProvider()),
        ChangeNotifierProvider(
          create: (_) => IntelligentTeleprompterProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
      ],
      child: MaterialApp(
        navigatorKey: RemoteCoordinator.instance.navigatorKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _sendScreenSize(context),
          );
          return child!;
        },
        home: Showcase.home() ?? const DocumentListScreen(),
      ),
    );
  }
}
