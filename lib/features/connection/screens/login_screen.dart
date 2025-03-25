import 'package:aybudle/core/constants/app_constants.dart';
import 'package:aybudle/features/connection/screens/post_login_screen.dart';
import 'package:aybudle/features/connection/view_models/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  final String baseUrl;
  const LoginScreen({Key? key, required this.baseUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (_) => LoginViewModel(baseUrl),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.loginText),
        ),
        body: Consumer<LoginViewModel>(
          builder: (context, viewModel, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: AppConstants.usernameText,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: viewModel.setUsername,
                    controller:
                        TextEditingController(text: viewModel.username),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: AppConstants.passwordText,
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: viewModel.setPassword,
                    controller:
                        TextEditingController(text: viewModel.password),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text(AppConstants.rememberMeText),
                    value: viewModel.rememberMe,
                    onChanged: viewModel.toggleRememberMe,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: viewModel.isLoading
                        ? null
                        : () async {
                            bool success = await viewModel.login();
                            if (success) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostLoginScreen(baseUrl: baseUrl, token: viewModel.getToken()),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                      content: Text(AppConstants.loginFailedText)));
                            }
                          },
                    child: const Text(AppConstants.loginButtonText),
                  ),
                  if (viewModel.isLoading) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
