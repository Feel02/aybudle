import 'package:dio/dio.dart';
import 'dart:developer' as developer; // Use aliased developer log

class ApiService {
  final Dio _dio = Dio();
  // Let's assume we want mocking only in debug mode
  // You can set this based on your build environment if needed
  static const bool kDebugMode = false; // Or use Foundation's kDebugMode

  ApiService() {
    // Add logging interceptor to see request/response details easily
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => developer.log(o.toString(), name: 'ApiServiceDio'),
    ));

    // --- Mock Interceptor (Use carefully for debugging) ---
    // make sure the wsfunction matches the one in getNotifications.
    /*
    if (kDebugMode) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          // Check if it's the specific notifications request we want to mock
          if (options.queryParameters['wsfunction'] == 'message_popup_get_popup_notifications') { // <-- Match the function used below
            developer.log('--- Using Mock Notifications ---', name: 'ApiServiceMock');
            // Mock response data
            final mockNotifications = { // The API likely returns a map
              'notifications': [
                {
                  'id': 1,
                  'useridfrom': 2, // Example field
                  'useridto': 32596, // Example field matching your user ID
                  'subject': 'Mock Notification 1 (Unread)',
                  'smallmessage': 'This is a test UNREAD notification!',
                  'fullmessage': 'This is the full message for the unread notification.',
                  'fullmessageformat': 1, // HTML format usually
                  'contexturl': 'https://aybuzem.aybu.edu.tr/course/view.php?id=123',
                  'contexturlname': 'Sample Course',
                  'timecreated': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
                  'timeread': null, // Key indicator for unread
                  'component': 'moodle', // Example
                  'eventtype': 'assign_due', // Example
                  'customdata': null // Example
                },
                {
                  'id': 2,
                  'useridfrom': 3,
                  'useridto': 32596,
                  'subject': 'Mock Notification 2 (Read)',
                  'smallmessage': 'Assignment due tomorrow (already read).',
                  'fullmessage': 'Full details about the assignment due tomorrow.',
                  'fullmessageformat': 1,
                  'contexturl': 'https://aybuzem.aybu.edu.tr/mod/assign/view.php?id=456',
                  'contexturlname': 'Assignment 1',
                  'timecreated': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
                  'timeread': DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, // Non-null indicates read
                  'component': 'mod_assign',
                  'eventtype': 'due_soon',
                  'customdata': '{"assignmentid": 456}' // Example
                },
              ],
              'unreadcount': 1 // The API often includes this
            };

            // Simulate a successful response
            handler.resolve(
              Response(
                requestOptions: options,
                data: mockNotifications, // Return the full map
                statusCode: 200,
              ),
            );
            return; // Stop processing, return mock
          }
          // Continue with the original request for other APIs
          developer.log('Passing request through: ${options.uri}', name: 'ApiServiceMock');
          handler.next(options);
        },
        onError: (e, handler) {
          developer.log('Mock Interceptor Error: ${e.message}', name: 'ApiServiceMock', error: e);
          handler.next(e); // Pass errors through
        }
      ));
    }
    */
     // --- End Mock Interceptor ---
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
    // No changes needed here, but ensure it works correctly
    try {
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'core_webservice_get_site_info',
          'moodlewsrestformat': 'json',
        },
      );
       if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
         return response.data;
       } else {
         throw Exception('Failed to get user info: Invalid response format or status code ${response.statusCode}');
       }
    } catch (e) {
      developer.log('Failed to get user info', name: 'ApiService', error: e);
      // Re-throw a more specific exception or handle it as needed
      throw Exception('Failed to get user info: $e');
    }
  }

  Future<List<dynamic>> getCourses(String baseUrl, String token, int userId) async {
     // No changes needed here, but ensure it works correctly
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
        if (response.statusCode == 200 && response.data is List) {
            return response.data;
        } else {
             throw Exception('Failed to get courses: Invalid response format or status code ${response.statusCode}');
        }
      } catch (e) {
        developer.log('Failed to get courses', name: 'ApiService', error: e);
        throw Exception('Failed to get courses: $e');
      }
  }

  Future<List<dynamic>> getCoursesContent(String baseUrl, String token, int courseId) async {
    // No changes needed here, but ensure it works correctly
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
         if (response.statusCode == 200 && response.data is List) {
            return response.data;
        } else {
            // Moodle might return an error object instead of a list
             if (response.data is Map && response.data.containsKey('exception')) {
                 developer.log('API Error getting content for course $courseId: ${response.data}', name: 'ApiService');
                 // Return an empty list or throw a specific error
                 return []; // Or throw Exception('API Error: ${response.data['message']}');
             }
             throw Exception('Failed to get course content for $courseId: Invalid response format or status code ${response.statusCode}');
        }
    } catch (e) {
        developer.log('Failed to get course content for $courseId', name: 'ApiService', error: e);
        throw Exception('Failed to get course content for $courseId: $e');
    }
  }


  /// Fetches notifications for the user.
  /// Returns the raw response data map which likely contains 'notifications' list and 'unreadcount'.
  Future<Map<String, dynamic>> getNotifications(String baseUrl, String token, int userId) async {
    developer.log('Fetching notifications with userId: $userId', name: 'ApiService');
    try {
      final response = await _dio.get(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'message_popup_get_popup_notifications',
          'moodlewsrestformat': 'json',
          'useridto': userId,
          // --- REMOVED Optional Parameters ---
          // 'limitnum': 50,
          // 'newestfirst': 1,
        },
      );

      // --- ADDED Moodle Error Check ---
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        // Check if the response contains a Moodle exception key
        if (responseData.containsKey('exception')) {
          developer.log('Moodle API Error received: ${responseData['message']} (${responseData['errorcode']})', name: 'ApiService', level: 1000);
          throw Exception('API Error: ${responseData['message']} (${responseData['errorcode']})');
        }
        // If no exception key, assume success
        developer.log('Successfully fetched notifications data.', name: 'ApiService');
        return responseData;
      } else {
         developer.log('Failed to get notifications: Status code ${response.statusCode}, Data type: ${response.data.runtimeType}', name: 'ApiService');
         throw Exception('Failed to get notifications: Invalid response format or status code ${response.statusCode}');
      }

    } on DioException catch (e) {
        developer.log('DioError fetching notifications: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
        developer.log('DioError Response: ${e.response?.data}', name: 'ApiService');
        String errorMsg = 'Network error fetching notifications.';
        if (e.response?.data is Map && e.response!.data.containsKey('message')) {
          // Try to extract Moodle error message from DioError response as well
          errorMsg = 'API Error: ${e.response!.data['message']}';
        } else if (e.message != null) {
          errorMsg = 'Network error: ${e.message}';
        }
        throw Exception(errorMsg);
    } catch (e, s) {
      developer.log('Error fetching notifications: $e', name: 'ApiService', error: e, stackTrace: s);
      // If the error was the Moodle exception we threw above, re-throw it
      if (e is Exception && e.toString().contains('API Error:')) {
          throw e;
      }
      // Otherwise, wrap it
      throw Exception('An unexpected error occurred while fetching notifications: ${e.toString()}');
    }
  }

   // --- Add function to mark notification as read ---
  Future<bool> markNotificationRead(String baseUrl, String token, int notificationId) async {
    developer.log('Marking notification $notificationId as read', name: 'ApiService');
    try {
      final response = await _dio.post( // Use POST as we are changing state
        "$baseUrl/webservice/rest/server.php",
        queryParameters: { // Common parameters go in query
          'wstoken': token,
          'wsfunction': 'core_message_mark_notification_read',
          'moodlewsrestformat': 'json',
        },
        data: { // Specific parameters for the function often go in data for POST
           'notificationid': notificationId,
           'timeread': DateTime.now().millisecondsSinceEpoch ~/ 1000, // Current time as read time
        }
      );

      if (response.statusCode == 200 && response.data is Map) {
         // Check for a success indicator or absence of error in the response
         // Moodle APIs often return a status or warning array. An empty warning array usually means success.
         if (response.data['warnings'] == null || (response.data['warnings'] as List).isEmpty) {
            developer.log('Successfully marked notification $notificationId as read.', name: 'ApiService');
            return true;
         } else {
            developer.log('API Warnings marking notification read: ${response.data['warnings']}', name: 'ApiService');
            // Decide if warnings should count as failure
            return false; // Or true depending on severity
         }
      } else {
         developer.log('Failed to mark notification read: Status code ${response.statusCode}, Data: ${response.data}', name: 'ApiService');
         return false;
      }
    } catch (e) {
      developer.log('Error marking notification read: $e', name: 'ApiService', error: e);
      return false;
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

