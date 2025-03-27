import 'package:aybudle/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class DiscussionPostsScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final int discussionId;

  const DiscussionPostsScreen({
    Key? key,
    required this.baseUrl,
    required this.token,
    required this.discussionId,
  }) : super(key: key);

  @override
  State<DiscussionPostsScreen> createState() => _DiscussionPostsScreenState();
}

class _DiscussionPostsScreenState extends State<DiscussionPostsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _discussionData;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final discussion = _apiService.getDiscussions(widget.baseUrl, widget.token, widget.discussionId);
    discussion.then((value) {
      setState(() {
        _discussionData = value;
        _isLoading = false;
      });
    });
  }

  Widget _buildPostWidget(Map<String, dynamic> post) {
    // Customize how you display each post.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(post['message'] ?? 'No message available'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Expecting the discussion data to have a structure with 'discussion' key and inside that a list of posts.
    final posts = _discussionData != null && _discussionData!['discussion'] != null
        ? (_discussionData!['discussion']['posts'] as List<dynamic>?) ?? []
        : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('No posts found.'))
              : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _buildPostWidget(post);
                  },
                ),
    );
  }
}
