import 'package:aybudle/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'discussion_posts_screen.dart';

class ForumDiscussionsScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  final int forumId;

  const ForumDiscussionsScreen({
    Key? key,
    required this.baseUrl,
    required this.token,
    required this.forumId,
  }) : super(key: key);

  @override
  State<ForumDiscussionsScreen> createState() => _ForumDiscussionsScreenState();
}

class _ForumDiscussionsScreenState extends State<ForumDiscussionsScreen> {
  bool _isLoading = true;
  List _discussions = [];
  ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final discussionForum = _apiService.getForumDiscussionsForum(widget.baseUrl, widget.token, widget.forumId);
    discussionForum.then((value) {
      setState(() {
        _discussions = value;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Discussions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _discussions.isEmpty
              ? const Center(child: Text('No discussions found.'))
              : ListView.builder(
                  itemCount: _discussions.length,
                  itemBuilder: (context, index) {
                    final discussion = _discussions[index];
                    return ListTile(
                      title: Text(discussion['name'] ?? 'No Title'),
                      subtitle: Text('Discussion ID: ${discussion['discussion']}'),
                      onTap: () {
                        // Navigate to DiscussionPostsScreen with discussion id.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiscussionPostsScreen(
                              baseUrl: widget.baseUrl,
                              token: widget.token,
                              discussionId: discussion['discussion'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
