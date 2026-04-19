import 'package:flutter/material.dart';
import 'package:locallink_mobile/config.dart';
import 'package:locallink_mobile/home.dart';

const config = AppConfig(
  baseUrl: String.fromEnvironment('BASE_URL'),
  apiKey: String.fromEnvironment('API_KEY'),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home(config: config));
  }
}

void main() {
  runApp(const MyApp());
}
