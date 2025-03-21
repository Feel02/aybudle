import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();

  Future<bool> validateMoodleUrl(String url) async {
    try {
      final response = await _dio.get(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> login(String baseUrl, String username, String password) async {
    try {
      final response = await _dio.get(
        "$baseUrl/login/token.php?username=$username&password=$password&service=moodle_mobile_app",
      );
      if (response.statusCode == 200 && response.data["token"] != null) {
        print(response.data);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
