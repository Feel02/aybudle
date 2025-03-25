import 'package:aybudle/core/constants/app_constants.dart';
import 'package:aybudle/features/connection/screens/login_screen.dart';
import 'package:aybudle/features/connection/screens/webview_screen.dart';
import 'package:aybudle/features/connection/view_models/connection_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  void _showChoiceDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Choose Option"),
          content: const Text("Do you want to open the URL directly or use the app login?"),
          actions: [
            TextButton(
              onPressed: () {
                // Option: Open URL directly (e.g., in WebView)
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebViewScreen(url: url),
                  ),
                );
              },
              child: const Text("Open URL"),
            ),
            TextButton(
              onPressed: () {
                // Option: Open in App (go to login)
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(baseUrl: url),
                  ),
                );
              },
              child: const Text("Open in App"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<ConnectionViewModel>(
          builder: (context, viewModel, _) {
            // Use a TextEditingController that persists state if needed.
            final urlController = TextEditingController(text: viewModel.url);
            return Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: AppConstants.urlHintText,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: viewModel.setUrl,
                  keyboardType: TextInputType.url,
                  controller: urlController,
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text(AppConstants.rememberMeText),
                  value: viewModel.rememberSite,
                  onChanged: viewModel.toggleRememberSite,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                          // Validate the URL connection first.
                          if (await viewModel.connectToSite()) {
                            // Instead of directly navigating to the login screen,
                            // show a dialog for the user to choose the desired action.
                            _showChoiceDialog(context, viewModel.url);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                    content: Text(AppConstants.invalidUrlText)),
                            );
                          }
                        },
                  child: const Text(AppConstants.connectButtonText),
                ),
                if (viewModel.isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ]
              ],
            );
          },
        ),
      ),
    );
  }
}
