import 'package:aybudle/core/constants/app_constants.dart';
import 'package:aybudle/features/connection/presentation/view_models/connection_view_model.dart';
import 'package:aybudle/features/connection/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<ConnectionViewModel>(
          builder: (context, viewModel, _) {
            return Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: AppConstants.urlHintText,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: viewModel.setUrl,
                  keyboardType: TextInputType.url,
                  controller: TextEditingController(text: viewModel.url),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text("Remember Site"),
                  value: viewModel.rememberSite,
                  onChanged: viewModel.toggleRememberSite,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                          if (await viewModel.connectToSite()) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoginScreen(baseUrl: viewModel.url),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Invalid URL or connection failed')),
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
