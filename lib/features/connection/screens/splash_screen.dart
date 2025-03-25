import 'package:aybudle/core/services/api_service.dart';
import 'package:aybudle/features/connection/screens/connection_screen.dart';
import 'package:aybudle/features/connection/screens/courses_screen.dart';
import 'package:aybudle/features/connection/view_models/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  final ApiService _apiService = ApiService();

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('rememberedUsername');
    final savedPassword = prefs.getString('rememberedPassword');
    final savedSite = prefs.getString('rememberedSite');
    
    // If credentials exist, automatically navigate to courses.
    if (savedUsername != null &&
        savedPassword != null &&
        savedSite != null) {
      // You may want to re-login via your API call to fetch a new token.
      // For now, we assume these credentials are valid:
      List result = await _apiService.login(savedSite, savedUsername, savedPassword);
      var token = result[1];
      if (token != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoursesScreen(baseUrl: savedSite, token: token),
          ),
        );
        return;
      }
    }
    // Otherwise, navigate to the ConnectionScreen.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ConnectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
