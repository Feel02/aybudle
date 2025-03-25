import 'package:flutter/material.dart';
import 'courses_screen.dart';

class PostLoginScreen extends StatelessWidget {
  final String baseUrl;
  final String token;

  const PostLoginScreen({
    Key? key,
    required this.baseUrl,
    required this.token,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Directly display the courses screen which will fetch and show courses details.
    return CoursesScreen(baseUrl: baseUrl, token: token);
  }
}
