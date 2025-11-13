import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/documents/providers/documents_provider.dart';
import 'features/editor/providers/editor_provider.dart';
import 'features/teleprompter/providers/teleprompter_provider.dart';
import 'features/teleprompter/providers/intelligent_teleprompter_provider.dart';
import 'features/remote/providers/server_provider.dart';
import 'features/documents/screens/document_list_screen.dart';
import 'services/remote_control_service.dart';

class FlutteleApp extends StatefulWidget {
  const FlutteleApp({super.key});

  @override
  State<FlutteleApp> createState() => _FlutteleAppState();
}

class _FlutteleAppState extends State<FlutteleApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate initialization delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _LoadingScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(create: (_) => EditorProvider()),
        ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ChangeNotifierProvider(create: (_) => IntelligentTeleprompterProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Get screen dimensions after first frame and update RemoteControlService
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final size = MediaQuery.of(context).size;
            // Assume landscape for teleprompter (width > height)
            final landscapeWidth = size.width > size.height ? size.width : size.height;
            final landscapeHeight = size.width > size.height ? size.height : size.width;
            
            RemoteControlService().updateTeleprompterState(
              -1,
              false,
              fontSize: 32.0,
              screenWidth: landscapeWidth,
              screenHeight: landscapeHeight,
            );
            print('📱 App initialized with screen dimensions: ${landscapeWidth}x$landscapeHeight');
          });
          
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const DocumentListScreen(),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App name
            const Text(
              'Vompt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Teleprompter',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
            // Shadcn-style loader
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
