import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/todo_viewmodel.dart';
import 'services/session_service.dart';
import 'views/login_view.dart';
import 'views/todo_list_view.dart';

void main() async {
  // Ensures Flutter binding is ready before executing platform-specific code
  WidgetsFlutterBinding.ensureInitialized();
  
  // SECURE PROTOCOL: Prevents screenshots and hides app content in the 
  // recent apps/multitasking view. Essential for a Secure Vault.
  await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => TodoViewModel()),
      ],
      child: const CipherTaskApp(),
    ),
  );
}

class CipherTaskApp extends StatefulWidget {
  const CipherTaskApp({super.key});

  @override
  State<CipherTaskApp> createState() => _CipherTaskAppState();
}

class _CipherTaskAppState extends State<CipherTaskApp> {
  late SessionService _sessionService; 
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize session timeout logic
    _sessionService = SessionService(onTimeout: () {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    });
    _sessionService.startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Resets the session timer on any user interaction
      onPointerDown: (_) => _sessionService.resetTimer(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Secure Vault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Poppins',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0DA6F2),
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginView(),
          '/todos': (context) => TodoListView(), 
        },
      ),
    );
  }
}