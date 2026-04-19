import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:locallink_mobile/config.dart';
import 'package:locallink_mobile/home.dart';

class MyApp extends StatelessWidget {
  final AppConfig config;
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Home(config: config));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = dotenv.DotEnv(includePlatformEnvironment: true);
  env.load(['.env']);
  runApp(
    MyApp(
      config: AppConfig(baseUrl: env['BASE_URL']!, apiKey: env['API_KEY']!),
    ),
  );
}
