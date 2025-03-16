import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aybudle/core/services/api_service.dart';

class LoginViewModel with ChangeNotifier {
  final String baseUrl;
  final ApiService _apiService = ApiService();

  String _username = '';
  String _password = '';
  bool _isLoading = false;
  bool _rememberMe = false;

  String get username => _username;
  String get password => _password;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;

  LoginViewModel(this.baseUrl) {
    _loadRememberedCredentials();
  }

  void setUsername(String value) {
    _username = value;
  }

  void setPassword(String value) {
    _password = value;
  }

  void toggleRememberMe(bool? value) async {
    _rememberMe = value ?? false;
    notifyListeners();
    // If disabling "Remember Me", clear saved credentials
    if (!_rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rememberedUsername');
      await prefs.remove('rememberedPassword');
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('rememberedUsername');
    final savedPassword = prefs.getString('rememberedPassword');
    if (savedUsername != null && savedPassword != null) {
      _username = savedUsername;
      _password = savedPassword;
      _rememberMe = true;
      notifyListeners();
    }
  }

  Future<bool> login() async {
    _isLoading = true;
    notifyListeners();

    bool result = await _apiService.login(baseUrl, _username, _password);

    _isLoading = false;
    notifyListeners();

    if (_rememberMe && result) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rememberedUsername', _username);
      await prefs.setString('rememberedPassword', _password);
    }
    return result;
  }
}
