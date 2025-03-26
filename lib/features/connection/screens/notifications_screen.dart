import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:aybudle/core/services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String baseUrl;
  final String token;

  const NotificationsScreen({
    Key? key,
    required this.baseUrl,
    required this.token,
  }) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      print('=== Starting notifications fetch ===');
      print('Base URL: ${widget.baseUrl}');
      print('Token: ${widget.token}');

      // Get user info
      print('\n=== Fetching user info ===');
      final userInfo = await _apiService.getUserInfo(widget.baseUrl, widget.token);
      print('Raw user info response:');
      print(userInfo);
      
      final userId = userInfo['userid'] as int;
      print('Extracted user ID: $userId');

      // Get notifications
      print('\n=== Fetching notifications ===');
      final notifications = await _apiService.getNotifications(widget.baseUrl, widget.token, userId);
      print('Raw notifications response:');
      print(notifications);

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      print('\n=== Final notifications data ===');
      print('Number of notifications: ${_notifications.length}');
      if (_notifications.isNotEmpty) {
        print('First notification:');
        print(_notifications.first);
      }
    } catch (e) {
      print('\n=== Error occurred ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      if (e is DioException) {
        print('Dio error details:');
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      setState(() => _isLoading = false);
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return ListTile(
      title: Text(notification['subject'] ?? 'No Subject'),
      subtitle: Text(notification['smallmessage'] ?? 'No message'),
      trailing: notification['timecreated'] != null
          ? Text(DateTime.fromMillisecondsSinceEpoch(
                  notification['timecreated'] * 1000)
              .toString()
              .split(' ')
              .first)
          : const Text(''),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications found.'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) =>
                      _buildNotificationItem(_notifications[index]),
                ),
    );
  }
}