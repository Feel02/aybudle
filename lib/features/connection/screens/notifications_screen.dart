import 'package:aybudle/core/constants/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:aybudle/core/services/api_service.dart';
import 'dart:developer' as developer;
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

enum NotificationFilter {
  all,
  read,
  unread,
}

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
  // Store the full response map initially, or just the list if preferred
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0; // Keep track of unread count
  String? _error; // Store potential error messages
  final ApiService _apiService = ApiService();
  int? _userId; // Store user ID after fetching
  NotificationFilter _selectedFilter = NotificationFilter.all;
  List<Map<String, dynamic>> _filteredNotifications = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _applyFilter(); // Initial filter application
  }

  Future<void> _fetchInitialData() async {
    // First, get the user ID if not already fetched elsewhere
    // In a real app, you might get this once after login and store it in a provider/state management solution
    if (_userId == null) {
       try {
          developer.log('Fetching user info for notifications...', name: 'NotificationsScreen');
          final userInfo = await _apiService.getUserInfo(widget.baseUrl, widget.token);
          // Defensive check for userid existence and type
          if (userInfo.containsKey('userid') && userInfo['userid'] is int) {
             _userId = userInfo['userid'] as int;
             developer.log('User ID obtained: $_userId', name: 'NotificationsScreen');
             await _fetchNotifications(); // Now fetch notifications
          } else {
             developer.log('User ID not found or invalid type in user info response: $userInfo', name: 'NotificationsScreen', level: 1000); // Log as error
             setState(() {
               _isLoading = false;
               _error = 'Could not retrieve user information.';
             });
          }
       } catch (e, s) {
          developer.log('Error fetching user info: $e', name: 'NotificationsScreen', error: e, stackTrace: s, level: 1000);
          setState(() {
            _isLoading = false;
            _error = 'Error getting user info: ${e.toString()}';
          });
       }
    } else {
       await _fetchNotifications(); // User ID already available
    }
  }

  void _applyFilter() {
      setState(() {
        switch (_selectedFilter) {
          case NotificationFilter.all:
            _filteredNotifications = _notifications;
            break;
          case NotificationFilter.read:
            _filteredNotifications = _notifications
                .where((n) => n['timeread'] != null)
                .toList();
            break;
          case NotificationFilter.unread:
            _filteredNotifications = _notifications
                .where((n) => n['timeread'] == null)
                .toList();
            break;
        }
      });
    }


  Future<void> _fetchNotifications() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notificationsResponse = await _apiService.getNotifications(
          widget.baseUrl, widget.token, _userId!);
      final List<dynamic> notificationsList =
          notificationsResponse['notifications'] as List<dynamic>? ?? [];
      final int unreadCount = notificationsResponse['unreadcount'] as int? ?? 0;

      setState(() {
        _notifications = notificationsList.whereType<Map<String, dynamic>>().toList();
        _unreadCount = unreadCount;
        _isLoading = false;
        _applyFilter(); // Apply filter after new data loads
      });
    } catch (e, s) {
      developer.log('\n=== Error occurred fetching notifications ===', name: 'NotificationsScreen', error: e, stackTrace: s, level: 1000);
      if (e is DioException) {
        developer.log('Dio error details:', name: 'NotificationsScreen', level: 1000);
        developer.log('Response data: ${e.response?.data}', name: 'NotificationsScreen', level: 1000);
        developer.log('Status code: ${e.response?.statusCode}', name: 'NotificationsScreen', level: 1000);
      }
      setState(() {
         _isLoading = false;
         _error = e.toString(); // Display error message
      });
    }
  }

  // Function to mark a notification as read
  Future<void> _markAsRead(int notificationId, int index) async {
    // Optimistic UI update
    setState(() {
      var updatedNotification = Map<String, dynamic>.from(_notifications[index]);
      updatedNotification['timeread'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _notifications[index] = updatedNotification;
      _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
      _applyFilter();
    });

    bool success = await _apiService.markNotificationRead(
      widget.baseUrl,
      widget.token,
      notificationId,
    );

    if (!success) {
      // If failed, revert UI and show error
      setState(() {
        var revertedNotification = Map<String, dynamic>.from(_notifications[index]);
        revertedNotification['timeread'] = null;
        _notifications[index] = revertedNotification;
        _unreadCount = (_unreadCount + 1).clamp(0, _notifications.length);
        _applyFilter();
      });
      
      await _fetchNotifications();
    } else {
      // Force refresh from server to confirm
      await _fetchNotifications();
    }
  }

  // Helper to format the date/time nicely
  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Consider using intl package for better date formatting
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final bool isRead = notification['timeread'] != null;
    final int timeCreated = notification['timecreated'] as int? ?? 0;
    final String subject = notification['subject'] as String? ?? 'No Subject';
    final String smallMessage = notification['smallmessage'] as String? ?? ''; // Usually plain text
    // final String fullMessage = notification['fullmessage'] as String? ?? ''; // Often HTML
    // final int fullMessageFormat = notification['fullmessageformat'] as int? ?? 0; // 1=HTML, 0=Markdown, 2=Plain, 4=Legacy Moodle Auto

    return ListTile(
      // Leading icon changes based on read status
      leading: Icon(
        isRead ? Icons.notifications_none : Icons.notifications_active,
        color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
      ),
      // Title is bolder if unread
      title: Text(
        subject,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      // Use small message as subtitle
      subtitle: Text(
          smallMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
      ),
      // Show relative time
      trailing: timeCreated > 0
          ? Text(
               _formatDateTime(timeCreated),
               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      isThreeLine: smallMessage.isNotEmpty, // Allow more space if subtitle exists
      onTap: () {
        developer.log('Tapped notification ID: ${notification['id']}', name: 'NotificationsScreen');

        // --- Show details in a dialog/bottom sheet ---
         showModalBottomSheet(
             context: context,
             isScrollControlled: true, // Allow full height
             builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.6, // Start at 60% height
                  minChildSize: 0.3,
                  maxChildSize: 0.9, // Allow almost full height
                  expand: false,
                  builder: (_, scrollController) => Container(
                       padding: const EdgeInsets.all(16.0),
                       child: ListView( // Use ListView for scrolling long content
                           controller: scrollController,
                           children: [
                               Text(
                                   subject,
                                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                   )
                               ),
                               const SizedBox(height: 8),
                               if (timeCreated > 0)
                                  Text(
                                      'Received: ${_formatDateTime(timeCreated)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                               const Divider(height: 24),
                               // Render HTML content safely
                               if (notification['fullmessage'] != null)
                                  Html(data: notification['fullmessage'] as String)
                               else
                                  Text(smallMessage), // Fallback to small message
                               const SizedBox(height: 20),
                               // Optionally add context link button
                               if (notification['contexturl'] != null && notification['contexturlname'] != null)
                                  ElevatedButton.icon(
                                      icon: const Icon(Icons.link),
                                      label: Text('Go to: ${notification['contexturlname']}'),
                                      onPressed: () {
                                          // Handle opening the context URL (e.g., in-app webview or external browser)
                                          developer.log('Open context URL: ${notification['contexturl']}', name: 'NotificationsScreen');
                                          Navigator.pop(context); // Close bottom sheet first
                                          // Add url_launcher logic here if needed
                                      },
                                  ),
                           ],
                       ),
                  ),
             ),
         );


        // --- Mark as read ---
        if (!isRead && notification['id'] != null) {
          _markAsRead(notification['id'] as int, index);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        itemCount: _filteredNotifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) =>
            _buildNotificationItem(_filteredNotifications[index], index),
      ),
    );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              const Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No notifications found.'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                   icon: const Icon(Icons.refresh),
                   label: const Text('Check Again'),
                   onPressed: _fetchNotifications,
              )
          ],
        )
      );
    }

    // Use RefreshIndicator for pull-to-refresh
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72), // Add separators
        itemBuilder: (context, index) =>
            _buildNotificationItem(_notifications[index], index),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Notifications ($_unreadCount unread)'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DropdownButton<NotificationFilter>(
            value: _selectedFilter,
            icon: const Icon(Icons.filter_list),
            underline: Container(),
            onChanged: (NotificationFilter? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedFilter = newValue;
                  _applyFilter();
                });
              }
            },
            items: const [
              DropdownMenuItem(
                value: NotificationFilter.all,
                child: Text(AppConstants.filterAll),
              ),
              DropdownMenuItem(
                value: NotificationFilter.unread,
                child: Text(AppConstants.filterUnread),
              ),
              DropdownMenuItem(
                value: NotificationFilter.read,
                child: Text(AppConstants.filterRead),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Notifications',
          onPressed: _isLoading ? null : _fetchNotifications,
        ),
      ],
    );
  }
}