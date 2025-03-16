import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectionViewModel with ChangeNotifier {
  String _url = '';
  bool _isLoading = false;

  String get url => _url;
  bool get isLoading => _isLoading;

  void setUrl(String value) {
    _url = value;
    notifyListeners();
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
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}