import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'notification_service.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // jangan biarkan kegagalan notifikasi/permission mematikan app
  try {
    await NotificationService.init();
  } catch (e, st) {
    debugPrint('⚠️ NotificationService.init() failed: $e\n$st');
  }

  try {
    // request permission hanya jika tersedia di platform
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.notification.request();
    }
  } catch (e, st) {
    debugPrint('⚠️ Permission.notification.request() failed: $e\n$st');
  }

  await Hive.initFlutter();
  await Hive.openBox('userBox');
  await Hive.openBox('savedNewsBox');
  final box = Hive.box('userBox');
  final user = box.get('user');

  runApp(
    MyApp(initialPage: user == null ? const RegisterPage() : const LoginPage()),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialPage;
  const MyApp({super.key, required this.initialPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Premium News+',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: initialPage,
    );
  }
}
