import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aybudle/core/services/api_service.dart';

class ConnectionViewModel with ChangeNotifier {
  String _url = '';
  bool _isLoading = false;
  bool _rememberSite = false;
  final ApiService _apiService = ApiService();

  String get url => _url;
  bool get isLoading => _isLoading;
  bool get rememberSite => _rememberSite;

  ConnectionViewModel() {
    _loadRememberedSite();
  }

  void setUrl(String value) {
    _url = value;
    notifyListeners();
    // If "Remember Site" is enabled, update the stored URL automatically
    if (_rememberSite) {
      _saveSite();
    }
  }

  void toggleRememberSite(bool? value) async {
    _rememberSite = value ?? false;
    notifyListeners();
    if (_rememberSite) {
      _saveSite();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rememberedSite');
    }
  }

  Future<void> _saveSite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rememberedSite', _url);
  }

  Future<void> _loadRememberedSite() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSite = prefs.getString('rememberedSite');
    if (savedSite != null && savedSite.isNotEmpty) {
      _url = savedSite;
      _rememberSite = true;
      notifyListeners();
    }
  }

  Future<bool> connectToSite() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (await canLaunchUrl(Uri.parse(_url))) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
