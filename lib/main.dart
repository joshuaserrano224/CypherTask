import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/todo_viewmodel.dart'; 
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/todo_list_view.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found.");
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        // AuthViewModel stays global to manage the login state
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        
        // REMOVED: TodoViewModel is no longer here. 
        // We will create it ONLY when a user successfully logs in.
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVM, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => authVM.resetSessionTimer(context),
          child: MaterialApp(
            title: 'CipherTask Vault',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF07090C),
              primaryColor: const Color(0xFF0DA6F2),
              fontFamily: 'Inter', 
            ),
            initialRoute: '/login', 
            // UPDATED ROUTES: Using OnGenerateRoute to inject the ViewModel dynamically
            onGenerateRoute: (settings) {
              if (settings.name == '/profile' || settings.name == '/todo_list') {
                return MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    // This creates a FRESH, EMPTY ViewModel every time the route is accessed
                    create: (_) => TodoViewModel(), 
                    child: const TodoListView(),
                  ),
                );
              }
              
              // Standard Routes
              if (settings.name == '/login') {
                return MaterialPageRoute(builder: (_) => const LoginView());
              }
              if (settings.name == '/register') {
                return MaterialPageRoute(builder: (_) => const RegisterView());
              }

              return null;
            },
          ),
        );
      },
    );
  }
}