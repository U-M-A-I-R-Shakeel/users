import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:users/screens/forget_password_screen.dart';
import 'package:users/screens/login_screen.dart';
import 'package:users/screens/main_screen.dart';
import 'package:users/screens/register_screen.dart';
import 'package:users/screens/profile_screen.dart';
import 'package:users/screens/search_places_screen.dart';
import 'package:users/screens/trips_history_screen.dart';
import 'package:users/splash_Screen/splash_screen.dart';
import 'package:users/theme_Provider/theme_provider.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trippo',
      themeMode: ThemeMode.system,
      theme: MyThemes.lightTheme,
      darkTheme: MyThemes.darkTheme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/forgetPassword': (context) => const ForgetPasswordScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/searchPlaces': (context) => const SearchPlacesScreen(),
        '/tripsHistory': (context) => const TripsHistoryScreen(),
      },
    );
  }
}
