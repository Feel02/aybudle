import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:aybudle/core/services/api_service.dart';
import 'dart:developer' as developer;
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
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


  Future<void> _fetchNotifications() async {
    if (_userId == null) {
       developer.log('Cannot fetch notifications: User ID is null.', name: 'NotificationsScreen', level: 1000);
       setState(() {
         _isLoading = false;
         _error = 'User ID not available.';
       });
       return;
    }

    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });

    try {
      developer.log('=== Starting notifications fetch ===', name: 'NotificationsScreen');
      developer.log('Base URL: ${widget.baseUrl}', name: 'NotificationsScreen');
      // Avoid logging token in production
      // developer.log('Token: ${widget.token}', name: 'NotificationsScreen');
      developer.log('User ID: $_userId', name: 'NotificationsScreen');

      // Get notifications response (expecting a Map)
      final notificationsResponse = await _apiService.getNotifications(widget.baseUrl, widget.token, _userId!);
      developer.log('Raw notifications response map:', name: 'NotificationsScreen');
      developer.log(notificationsResponse.toString(), name: 'NotificationsScreen');

      // Extract the list and unread count
      final List<dynamic> notificationsList = notificationsResponse['notifications'] as List<dynamic>? ?? [];
      final int unreadCount = notificationsResponse['unreadcount'] as int? ?? 0;

       // Ensure all items in the list are Maps
      final List<Map<String, dynamic>> typedNotifications = notificationsList
          .whereType<Map<String, dynamic>>() // Filter out non-map items if any
          .toList();

      setState(() {
        _notifications = typedNotifications;
        _unreadCount = unreadCount; // Update unread count
        _isLoading = false;
      });

      developer.log('\n=== Processed notifications data ===', name: 'NotificationsScreen');
      developer.log('Number of notifications: ${_notifications.length}', name: 'NotificationsScreen');
      developer.log('Reported unread count: $_unreadCount', name: 'NotificationsScreen');
      if (_notifications.isNotEmpty) {
        developer.log('First notification details:', name: 'NotificationsScreen');
        developer.log(_notifications.first.toString(), name: 'NotificationsScreen');
      }
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
    // Optimistically update the UI first
    setState(() {
      // Find the notification and update its timeread locally
      // Create a mutable copy if needed
      // Note: This assumes 'timeread' is the field indicating read status. Adjust if needed.
       var updatedNotification = Map<String, dynamic>.from(_notifications[index]);
       if (updatedNotification['timeread'] == null) {
          updatedNotification['timeread'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          _notifications[index] = updatedNotification;
          _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length); // Decrement unread count
       }
    });

    // Call the API to mark as read
    bool success = await _apiService.markNotificationRead(widget.baseUrl, widget.token, notificationId);

    if (!success) {
      developer.log('Failed to mark notification $notificationId as read on server.', name: 'NotificationsScreen', level: 900); // Log as warning
      // Optionally revert the UI change or show a snackbar
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark notification as read on server.')),
       );
       // Revert UI change (optional, might cause flicker)
       /* setState(() {
          var revertedNotification = Map<String, dynamic>.from(_notifications[index]);
           if (revertedNotification['timeread'] != null) { // Check if it was actually changed
              revertedNotification['timeread'] = null;
              _notifications[index] = revertedNotification;
              _unreadCount++; // Increment back
           }
       }); */
       // Or just refresh the list entirely to get the true state
       // await _fetchNotifications();
    } else {
       developer.log('Successfully marked notification $notificationId as read on server.', name: 'NotificationsScreen');
       // UI is already updated, maybe refresh the count from API if needed
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
      appBar: AppBar(
         title: Text('Notifications ($_unreadCount unread)'),
         actions: [
             // Add a refresh button
             IconButton(
                 icon: const Icon(Icons.refresh),
                 tooltip: 'Refresh Notifications',
                 onPressed: _isLoading ? null : _fetchNotifications, // Disable while loading
             ),
         ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.error_outline, color: Colors.red, size: 48),
                 const SizedBox(height: 16),
                 Text('Error loading notifications:', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                 const SizedBox(height: 8),
                 Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                 const SizedBox(height: 20),
                 ElevatedButton.icon(
                   icon: const Icon(Icons.refresh),
                   label: const Text('Retry'),
                   onPressed: _fetchInitialData, // Retry fetching everything including user ID if needed
                 )
              ],
           ),
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
}