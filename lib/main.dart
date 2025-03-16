// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/connection/presentation/screens/connection_screen.dart';
import 'features/connection/presentation/view_models/connection_view_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionViewModel()),
      ],
      child: MaterialApp(
        title: 'Moodle Connect',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const ConnectionScreen(),
      ),
    );
  }
}