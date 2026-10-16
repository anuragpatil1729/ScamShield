import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_navigation_screen.dart';
import 'services/message_repository.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final repository = MessageRepository();

  runApp(ScamShieldApp(repository: repository));
}

class ScamShieldApp extends StatelessWidget {
  final MessageRepository repository;

  const ScamShieldApp({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamShield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomeNavigationScreen(repository: repository),
    );
  }
}
