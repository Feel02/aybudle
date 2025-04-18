import 'package:dio/dio.dart';
import 'dart:developer' as developer; // Use aliased developer log

import 'package:aybudle/core/constants/app_constants.dart'; // Import constants for error messages

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
      // Add a timeout to prevent hanging indefinitely
      final response = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 10)));
      // Check for common Moodle page elements if status code isn't enough
      // For now, just checking status code
      return response.statusCode == 200;
    } catch (e) {
      developer.log('URL validation failed for $url: $e', name: 'ApiService');
      return false;
    }
  }

  /// Logs in the user and returns a list: [bool success, String? tokenOrError].
  /// Uses queryParameters for consistency.
  Future<List<dynamic>> login(String baseUrl, String username, String password) async {
    final String loginUrl = "$baseUrl/login/token.php"; // Base URL path for the token endpoint
    try {
      developer.log('Attempting login to: $loginUrl with username: $username', name: 'ApiService');
      final response = await _dio.get(
        loginUrl, // Use the base URL path here
        queryParameters: { // Pass parameters in the map
          'username': username,
          'password': password,
          'service': 'moodle_mobile_app', // Keep the required service parameter
        },
        options: Options(
          // Set a reasonable timeout for login requests
          receiveTimeout: const Duration(seconds: 15),
          // headers: {'Accept': 'application/json'}, // Usually not needed for GET token
        ),
      );

      // Check response status and data structure
      if (response.statusCode == 200 && response.data is Map) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData.containsKey('token') && responseData['token'] != null) {
          developer.log('Login successful, token received.', name: 'ApiService');
          return [true, responseData['token']];
        } else if (responseData.containsKey('error')) {
          // Moodle often returns a 200 OK with an error message in the body for bad credentials
          String errorMsg = responseData['error'] ?? AppConstants.invalidCredentialsText;
          developer.log('Login failed (API Error): $errorMsg | Error Code: ${responseData['errorcode']}', name: 'ApiService', level: 900);
          return [false, errorMsg]; // Return the specific error message
        } else {
          // Successful status code but unexpected data format
           developer.log('Login failed: Status 200 but token missing and no error key found. Response: $responseData', name: 'ApiService', level: 900);
           return [false, AppConstants.loginFailedText]; // Generic failure
        }
      } else {
        // Handle non-200 status codes
        developer.log('Login failed: Status code ${response.statusCode}. Response: ${response.data}', name: 'ApiService', level: 900);
        return [false, '${AppConstants.loginFailedText} (Status: ${response.statusCode})'];
      }
    } on DioException catch (e) { // Catch Dio specific errors
        developer.log('Login DioError: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace, level: 1000);
        developer.log('DioError Response: ${e.response?.data}', name: 'ApiService', level: 1000);

        String errorMessage = AppConstants.loginFailedText; // Default error
        // Try to extract Moodle error from Dio error response if available
        if (e.response?.data is Map && e.response!.data.containsKey('error')) {
            errorMessage = e.response!.data['error'] ?? errorMessage;
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.sendTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Connection timed out. Please try again.';
        } else if (e.type == DioExceptionType.unknown || e.type == DioExceptionType.connectionError) {
            // This often covers DNS resolution issues, network unreachable, etc.
            errorMessage = 'Network error. Please check your connection and the site URL.';
        } else if (e.response != null) {
            // Other HTTP errors (404, 500 etc.)
             errorMessage = '${AppConstants.loginFailedText} (Server Error: ${e.response?.statusCode})';
        }
        return [false, errorMessage]; // Return the determined error message
    } catch (e, s) { // Catch any other unexpected errors
      developer.log('Login unexpected error: $e', name: 'ApiService', error: e, stackTrace: s, level: 1000);
      return [false, 'An unexpected error occurred during login.'];
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
         // Check for Moodle API error within the response data
         final responseData = response.data as Map<String, dynamic>;
         if (responseData.containsKey('exception')) {
           developer.log('Moodle API Error getting user info: ${responseData['message']} (${responseData['errorcode']})', name: 'ApiService', level: 1000);
           throw Exception('API Error: ${responseData['message']} (${responseData['errorcode']})');
         }
         return responseData;
       } else {
         developer.log('Failed to get user info: Status code ${response.statusCode}, Data type: ${response.data?.runtimeType}', name: 'ApiService');
         throw Exception('Failed to get user info: Invalid response format or status code ${response.statusCode}');
       }
    } on DioException catch (e) {
        developer.log('DioError getting user info: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
        developer.log('DioError Response: ${e.response?.data}', name: 'ApiService');
        String errorMsg = 'Network error getting user info.';
        if (e.response?.data is Map && e.response!.data.containsKey('message')) {
          errorMsg = 'API Error: ${e.response!.data['message']}';
        } else if (e.message != null) {
           errorMsg = 'Network error: ${e.message}';
        }
        throw Exception(errorMsg);
    } catch (e, s) {
      developer.log('Failed to get user info: $e', name: 'ApiService', error: e, stackTrace: s);
      // Re-throw a more specific exception or handle it as needed
      if (e is Exception && e.toString().contains('API Error:')) {
         throw e; // Re-throw Moodle API errors we caught earlier
      }
      throw Exception('An unexpected error occurred while getting user info: ${e.toString()}');
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
        if (response.statusCode == 200) {
            // Moodle might return an error object instead of a list if permissions are wrong etc.
            if (response.data is List) {
                return response.data;
            } else if (response.data is Map && response.data.containsKey('exception')) {
                developer.log('API Error getting courses: ${response.data['message']} (${response.data['errorcode']})', name: 'ApiService', level: 1000);
                throw Exception('API Error: ${response.data['message']} (${response.data['errorcode']})');
            } else {
                // Unexpected format even with 200 status
                developer.log('Failed to get courses: Expected List but got ${response.data.runtimeType}', name: 'ApiService');
                throw Exception('Failed to get courses: Unexpected response format');
            }
        } else {
             developer.log('Failed to get courses: Status code ${response.statusCode}, Data: ${response.data}', name: 'ApiService');
             throw Exception('Failed to get courses: Invalid status code ${response.statusCode}');
        }
      } on DioException catch (e) {
          developer.log('DioError getting courses: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
          String errorMsg = 'Network error getting courses.';
          if (e.response?.data is Map && e.response!.data.containsKey('message')) {
             errorMsg = 'API Error: ${e.response!.data['message']}';
          } else if (e.message != null) {
             errorMsg = 'Network error: ${e.message}';
          }
          throw Exception(errorMsg);
      } catch (e, s) {
        developer.log('Failed to get courses: $e', name: 'ApiService', error: e, stackTrace: s);
        if (e is Exception && e.toString().contains('API Error:')) {
            throw e;
        }
        throw Exception('An unexpected error occurred while getting courses: ${e.toString()}');
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
         if (response.statusCode == 200) {
             if (response.data is List) {
                return response.data;
             } else if (response.data is Map && response.data.containsKey('exception')) {
                 developer.log('API Error getting content for course $courseId: ${response.data['message']} (${response.data['errorcode']})', name: 'ApiService', level: 900); // Warning level maybe
                 // Decide whether to throw or return empty. Returning empty might be better UX.
                 // throw Exception('API Error: ${response.data['message']} (${response.data['errorcode']})');
                 return []; // Return empty list on specific content error
             } else {
                 developer.log('Failed to get course content for $courseId: Expected List but got ${response.data.runtimeType}', name: 'ApiService');
                 throw Exception('Failed to get course content for $courseId: Unexpected response format');
             }
        } else {
            developer.log('Failed to get course content for $courseId: Status code ${response.statusCode}, Data: ${response.data}', name: 'ApiService');
             throw Exception('Failed to get course content for $courseId: Invalid status code ${response.statusCode}');
        }
    } on DioException catch (e) {
        developer.log('DioError getting course content for $courseId: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
        String errorMsg = 'Network error getting course content for $courseId.';
        if (e.response?.data is Map && e.response!.data.containsKey('message')) {
          errorMsg = 'API Error: ${e.response!.data['message']}';
        } else if (e.message != null) {
          errorMsg = 'Network error: ${e.message}';
        }
        // Depending on UX, might want to return [] instead of throwing
        // return [];
        throw Exception(errorMsg);
    } catch (e, s) {
        developer.log('Failed to get course content for $courseId: $e', name: 'ApiService', error: e, stackTrace: s);
        if (e is Exception && e.toString().contains('API Error:')) {
            // Maybe return [] here too?
             return [];
            // throw e;
        }
        // return [];
        throw Exception('An unexpected error occurred while getting content for course $courseId: ${e.toString()}');
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
      final response = await _dio.post(
        "$baseUrl/webservice/rest/server.php",
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'core_message_mark_notification_read',
          'moodlewsrestformat': 'json',
          'notificationid': notificationId, // Move notificationid to query parameters
        },
      );

      if (response.statusCode == 200) {
        // Successful response should be empty array for this API
        if (response.data is List && (response.data as List).isEmpty) {
          developer.log('Successfully marked notification $notificationId as read.', name: 'ApiService');
          return true;
        }
        // Handle unexpected response format
        developer.log('Unexpected response format: ${response.data}', name: 'ApiService');
        return false;
      } else {
        developer.log('Failed to mark notification read: Status code ${response.statusCode}', name: 'ApiService');
        return false;
      }
    } on DioException catch (e) {
      developer.log('DioError marking notification read: ${e.message}', name: 'ApiService', error: e);
      return false;
    } catch (e, s) {
      developer.log('Error marking notification read: $e', name: 'ApiService', error: e, stackTrace: s);
      return false;
    }
  }

  Future<Map<String, dynamic>> getDiscussions(String baseUrl, String token, int discussionId) async {
    final String serverUrl = '$baseUrl/webservice/rest/server.php';
    developer.log('Fetching discussion details for ID: $discussionId', name: 'ApiService');
    try {
      final response = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'mod_forum_get_forum_discussion_posts', // Updated function based on common Moodle API names - check your Moodle version!
          // 'wsfunction': 'mod_forum_get_discussion_posts', // Another possibility
          'moodlewsrestformat': 'json',
          'discussionid': discussionId,
          // Optional parameters:
          // 'sortby': 'created', // Default
          // 'sortdirection': 'ASC', // Default
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
         final responseData = response.data as Map<String, dynamic>;
         if (responseData.containsKey('exception')) {
           developer.log('Moodle API Error getting discussion $discussionId: ${responseData['message']} (${responseData['errorcode']})', name: 'ApiService', level: 1000);
           throw Exception('API Error: ${responseData['message']} (${responseData['errorcode']})');
         }
         developer.log('Successfully fetched discussion $discussionId.', name: 'ApiService');
         return responseData; // Should contain 'posts' list, 'ratinginfo', etc.
       } else {
         developer.log('Failed to get discussion $discussionId: Status code ${response.statusCode}, Data type: ${response.data?.runtimeType}', name: 'ApiService');
         throw Exception('Failed to get discussion $discussionId: Invalid response format or status code ${response.statusCode}');
       }
    } on DioException catch (e) {
        developer.log('DioError getting discussion $discussionId: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
        String errorMsg = 'Network error getting discussion $discussionId.';
        if (e.response?.data is Map && e.response!.data.containsKey('message')) {
          errorMsg = 'API Error: ${e.response!.data['message']}';
        }
        throw Exception(errorMsg);
    } catch (e, s) {
      developer.log('Error fetching discussion data for $discussionId: $e', name: 'ApiService', error: e, stackTrace: s, level: 1000);
       if (e is Exception && e.toString().contains('API Error:')) {
            throw e;
       }
      throw Exception('An unexpected error occurred while fetching discussion $discussionId: ${e.toString()}');
    }
  }

  Future<List> getForumDiscussionsForum(String baseUrl, String token, int forumId) async {
    final String serverUrl = '$baseUrl/webservice/rest/server.php';
     developer.log('Fetching discussions for forum ID: $forumId', name: 'ApiService');
    try {
      final response = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': token,
          'wsfunction': 'mod_forum_get_forum_discussions', // Correct function name seems to be used
          'moodlewsrestformat': 'json',
          'forumid': forumId,
           // Optional parameters:
           // 'sortorder': -1, // Sort by time modified DESC (default)
           // 'page': 0, // Page number
           // 'perpage': 0, // All discussions (default)
           // 'groupid': 0, // Specific group
        },
      );

     if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
         if (responseData.containsKey('exception')) {
           developer.log('Moodle API Error getting forum $forumId discussions: ${responseData['message']} (${responseData['errorcode']})', name: 'ApiService', level: 1000);
           throw Exception('API Error: ${responseData['message']} (${responseData['errorcode']})');
         }
         // Expecting a map containing a 'discussions' list
         if (responseData.containsKey('discussions') && responseData['discussions'] is List) {
             developer.log('Successfully fetched ${responseData['discussions'].length} discussions for forum $forumId.', name: 'ApiService');
             return responseData['discussions'] as List;
         } else {
             developer.log('Failed to get discussions for forum $forumId: "discussions" key missing or not a list. Response: $responseData', name: 'ApiService');
             throw Exception('Failed to get discussions for forum $forumId: Unexpected response structure.');
         }
     } else {
         developer.log('Failed to get discussions for forum $forumId: Status code ${response.statusCode}, Data type: ${response.data?.runtimeType}', name: 'ApiService');
         throw Exception('Failed to get discussions for forum $forumId: Invalid response format or status code ${response.statusCode}');
     }
    } on DioException catch (e) {
        developer.log('DioError getting discussions for forum $forumId: ${e.message}', name: 'ApiService', error: e, stackTrace: e.stackTrace);
        String errorMsg = 'Network error getting discussions for forum $forumId.';
        if (e.response?.data is Map && e.response!.data.containsKey('message')) {
          errorMsg = 'API Error: ${e.response!.data['message']}';
        }
        // Decide: throw or return []? Returning empty might be better UX.
        // throw Exception(errorMsg);
        return [];
    } catch (e, s) {
      developer.log('Error fetching discussions for forum $forumId: $e', name: 'ApiService', error: e, stackTrace: s, level: 1000);
       if (e is Exception && e.toString().contains('API Error:')) {
            // throw e;
            return []; // Return empty on API error too
       }
       // return []; // Return empty on other errors
       throw Exception('An unexpected error occurred while fetching discussions for forum $forumId: ${e.toString()}');
    }
  }
}