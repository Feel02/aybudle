import 'package:aybudle/core/constants/app_constants.dart';
import 'package:aybudle/core/services/api_service.dart';
import 'package:aybudle/features/connection/screens/connection_screen.dart';
import 'package:aybudle/features/connection/screens/forum_discussion_screen.dart';
import 'package:aybudle/features/connection/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoursesScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const CoursesScreen({
    Key? key,
    required this.baseUrl,
    required this.token,
  }) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _isLoading = true;
  final ApiService _apiService = ApiService();
  // This will store a list of maps. Each map contains:
  // 'course': the course info (Map) and 'contents': the course contents (raw response)
  List<Map<String, dynamic>> _coursesDetails = [];

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    fetchAllCoursesAndDetails();
  }

  Future<void> fetchAllCoursesAndDetails() async {
    try {
      final String serverUrl = '${widget.baseUrl}/webservice/rest/server.php';
      print("ADNJLJSJVJSKDJVLSDJKVSDLJVSKLDJVD");
      print(serverUrl);
      var userResponse = await _apiService.getUserInfo(widget.baseUrl, widget.token);

      print('--- Raw user response ---');
      print(userResponse);
      
      // 2. Get the course informations with the userResponse
      final coursesResponse = await _apiService.getCourses(widget.baseUrl, widget.token, userResponse['userid']);

      print('--- Raw courses response ---');
      print(coursesResponse);

      List coursesList = coursesResponse;

      List<Map<String, dynamic>> coursesDetails = [];

      // 2. For each course, fetch course contents.
      for (var course in coursesList) {
        final courseId = course['id'];
        final contentsResponse = await _apiService.getCoursesContent(widget.baseUrl, widget.token, courseId);

        print('--- Raw contents response for course id $courseId ---');
        print(contentsResponse);

        // Check if contentsResponse.data is a List. If not, log it.
        if (contentsResponse is List) {
          coursesDetails.add({
            'course': course,
            'contents': contentsResponse,
          });
        } else if (contentsResponse is Map<String, dynamic>) {
          // This might be an error response for the course.
          print('Error or unexpected structure for course id $courseId:');
          print(contentsResponse);
          coursesDetails.add({
            'course': course,
            'contents': null,
            'error': contentsResponse,
          });
        } else {
          print('Unexpected contents type for course id $courseId: ${contentsResponse.runtimeType}');
          coursesDetails.add({
            'course': course,
            'contents': null,
          });
        }
      }

      setState(() {
        _coursesDetails = coursesDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching courses details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Build a widget to display one course and its details
  Widget _buildCourseTile(Map<String, dynamic> courseDetail) {
    final course = courseDetail['course'] as Map<String, dynamic>;
    final contents = courseDetail['contents'];
    final error = courseDetail['error'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        title: Text(course['fullname'] ?? 'Unnamed Course'),
        subtitle: Text('Course ID: ${course['id']}'),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${error['message'] ?? error}',
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (contents != null && contents is List && contents.isNotEmpty)
            ...contents.map<Widget>((section) {
              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: ExpansionTile(
                  title: Text(section['name'] ?? 'Unnamed Section'),
                  subtitle: Text('Section ID: ${section['id']}'),
                  children: (section['modules'] as List<dynamic>).map<Widget>((module) {
                    return ListTile(
                      title: Text(module['name'] ?? 'Unnamed Module'),
                      subtitle: Text('Type: ${module['modname']}, Visible: ${module['visible']}'),
                      onTap: () {
                        if (module['modname'] == 'forum') {
                          // Navigate to ForumDiscussionsScreen using the token and forum id (module['instance'])
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ForumDiscussionsScreen(
                                baseUrl: widget.baseUrl,
                                token: widget.token,
                                forumId: module['instance'],
                              ),
                            ),
                          );
                        } else {
                          // For other module types, you can add similar logic or a fallback.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('This module type is not supported yet.')),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            }).toList()
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No contents available.'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses Details'),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            // Check if "Remember Me" is enabled.
            bool rememberMe = prefs.getBool('rememberMeEnabled') ?? false;
            
            if (!rememberMe) {
              // Clear everything if the user did NOT choose "Remember Me".
              await prefs.remove('rememberedUsername');
              await prefs.remove('rememberedPassword');
              await prefs.remove('rememberedSite');
            } else {
              // If "Remember Me" is enabled, clear only session-related data (e.g., token)
              await prefs.remove('userToken');
              // Optionally, you can update other session flags as needed.
            }
            
            // Navigate back to ConnectionScreen (clearing the navigation stack)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  baseUrl: widget.baseUrl,
                  token: widget.token,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coursesDetails.isEmpty
              ? const Center(child: Text(AppConstants.noCoursesText))
              : ListView.builder(
                  itemCount: _coursesDetails.length,
                  itemBuilder: (context, index) {
                    return _buildCourseTile(_coursesDetails[index]);
                  },
                ),
    );
  }

}
