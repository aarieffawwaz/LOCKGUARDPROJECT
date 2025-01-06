// main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'auth_checker.dart';
import 'firebase_options.dart'; // Import the generated Firebase options file

// Importing screens
import 'screens/dashboard_screen.dart'; // Updated path
import 'login_page.dart'; // Assuming you have a LoginPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the options for your platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use the generated FirebaseOptions
  );

  // Request notification permission
  await _requestNotificationPermission();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermission() async {
  // Check if the permission is already granted
  if (await Permission.notification.isDenied) {
    // Request the permission
    PermissionStatus status = await Permission.notification.request();

    if (status.isDenied) {
      // Permission denied, handle accordingly.
      // You can show a dialog explaining why the permission is needed
      print('Notification permission denied');
    } else if (status.isPermanentlyDenied) {
      // The user opted to never again see the permission request dialog for this app.
      // The only way to change the permission's status now is to let the user manually enable it in the system settings.
      await openAppSettings();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockGuard', // Added title for better identification
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, // Define a primary color
      ),
      home: const AuthChecker(),
    );
  }
}
