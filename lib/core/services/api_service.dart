import 'dart:ffi';

import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();
  var kDebugMode = true;

  ApiService() {
    // Add this interceptor for testing notifications
    if (kDebugMode) { // Only in debug mode
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Check if it's a notifications request
          if (options.queryParameters['wsfunction'] == 'core_message_get_notifications') {
            // Mock response data
            final mockNotifications = [
              {
                'id': 1,
                'subject': 'Mock Notification 1',
                'smallmessage': 'This is a test notification!',
                'timecreated': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
              },
              {
                'id': 2,
                'subject': 'Assignment Due',
                'smallmessage': 'Your assignment is due tomorrow!',
                'timecreated': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
              },
            ];

            // Simulate a successful response
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'notifications': mockNotifications},
              ),
            );
            return;
          }
          // Continue with the original request for other APIs
          handler.next(options);
        },
      ));
    }
  }

  Future<bool> validateMoodleUrl(String url) async {
    try {
      final response = await _dio.get(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List> login(String baseUrl, String username, String password) async {
    try {
      final response = await _dio.get(
        "$baseUrl/login/token.php?username=$username&password=$password&service=moodle_mobile_app",
      );
      if (response.statusCode == 200 && response.data["token"] != null) {
        print(response.data);
        return [true, response.data["token"]];
      }
      return [false,null];
    } catch (e) {
      return [false,null];
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String baseUrl, String token) async {
    try {
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'core_webservice_get_site_info',
          'moodlewsrestformat': 'json',
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to get user info: $e');
    }
  }

  Future<List<dynamic>> getCourses(String baseUrl, String token, int userId) async {
    try {
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'core_enrol_get_users_courses',
          'moodlewsrestformat': 'json',
          'userid': userId,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to get courses: $e');
    }
  }

  Future<List<dynamic>> getCoursesContent(String baseUrl, String token, int courseId) async {
    try {
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'core_course_get_contents',
          'moodlewsrestformat': 'json',
          'courseid': courseId,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to get course content: $e');
    }
  }

  Future<List<dynamic>> getNotifications(String baseUrl, String token, int userId) async {
    try {
      // Try alternative API endpoints
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          //'wsfunction': 'core_message_get_popup_notifications', // Alternative 1
          'wsfunction': 'core_message_get_notifications',    // Alternative 2
          'moodlewsrestformat': 'json',
          'useridto': userId,
          'limitnum': 20,  // Add pagination
        },
      );

      return response.data['notifications'] ?? [];
    } catch (e) {
      print('Error trying alternative notification APIs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDiscussions(String baseUrl, String token, int discussionId) async {
    final String serverUrl = '$baseUrl/webservice/rest/server.php';
    try {
      final response = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'mod_forum_get_forum_discussion',
          'moodlewsrestformat': 'json',
          'discussionid': discussionId,
        },
      );

      return response.data;
    } catch (e) {
      print('Error fetching discussion data: $e');
      return {};
    }
  }

  Future<List> getForumDiscussionsForum(String baseUrl, String token, int forumId) async {
    final String serverUrl = '$baseUrl/webservice/rest/server.php';
    try {
      final response = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'mod_forum_get_forum_discussions',
          'moodlewsrestformat': 'json',
          'forumid': forumId,
        },
      );
     
      return response.data['discussions'];
    } catch (e) {
      print('Error fetching discussions: $e');
      return [];
    }
  }
}

