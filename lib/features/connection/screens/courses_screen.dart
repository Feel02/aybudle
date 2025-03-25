import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

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
    final String serverUrl = '${widget.baseUrl}/webservice/rest/server.php';
    print("ADNJLJSJVJSKDJVLSDJKVSDLJVSKLDJVD");
    print(serverUrl);
    try {
      // 1. Fetch user informations
      final userResponse = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': widget.token,
          'wsfunction': 'core_webservice_get_site_info',
          'moodlewsrestformat': 'json',
        },
      );

      print('--- Raw user response ---');
      print(userResponse.data);
      
      // 2. Get the course informations with the userResponse
      final coursesResponse = await _dio.get(
        serverUrl,
        queryParameters: {
          'wstoken': widget.token,
          'wsfunction': 'core_enrol_get_users_courses',
          'moodlewsrestformat': 'json',
          'userid': userResponse.data['userid'],
        },
      );

      print('--- Raw courses response ---');
      print(coursesResponse.data);

      List coursesList = coursesResponse.data;

      List<Map<String, dynamic>> coursesDetails = [];

      // 2. For each course, fetch course contents.
      for (var course in coursesList) {
        final courseId = course['id'];
        final contentsResponse = await _dio.get(
          serverUrl,
          queryParameters: {
            'wstoken': widget.token,
            'wsfunction': 'core_course_get_contents',
            'moodlewsrestformat': 'json',
            'courseid': courseId,
          },
        );

        print('--- Raw contents response for course id $courseId ---');
        print(contentsResponse.data);

        // Check if contentsResponse.data is a List. If not, log it.
        if (contentsResponse.data is List) {
          coursesDetails.add({
            'course': course,
            'contents': contentsResponse.data,
          });
        } else if (contentsResponse.data is Map<String, dynamic>) {
          // This might be an error response for the course.
          print('Error or unexpected structure for course id $courseId:');
          print(contentsResponse.data);
          coursesDetails.add({
            'course': course,
            'contents': null,
            'error': contentsResponse.data,
          });
        } else {
          print('Unexpected contents type for course id $courseId: ${contentsResponse.data.runtimeType}');
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
                      subtitle: Text(
                        'Type: ${module['modname']}, Visible: ${module['visible']}',
                      ),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coursesDetails.isEmpty
              ? const Center(child: Text('No courses found'))
              : ListView.builder(
                  itemCount: _coursesDetails.length,
                  itemBuilder: (context, index) {
                    return _buildCourseTile(_coursesDetails[index]);
                  },
                ),
    );
  }
}
