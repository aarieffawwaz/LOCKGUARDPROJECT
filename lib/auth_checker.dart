// auth_checker.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:testing/screens/dashboard_screen.dart'; // Update the path accordingly
import 'login_page.dart';

class AuthChecker extends StatelessWidget {
  const AuthChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Stream of auth changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While waiting for authentication status, show a loading indicator
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // If the user is logged in, navigate to DashboardPage
          return const DashboardPage();
        }

        // If the user is not logged in, navigate to LoginPage
        return const LoginPage();
      },
    );
  }
}
