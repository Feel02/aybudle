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
}