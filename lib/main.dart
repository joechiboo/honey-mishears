import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 這個 App 只做直式
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const HoneyMishearsApp());
}

class HoneyMishearsApp extends StatelessWidget {
  const HoneyMishearsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomePage(),
    );
  }
}
