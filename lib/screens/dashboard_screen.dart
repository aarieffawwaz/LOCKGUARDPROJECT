// /screens/dashboard_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_checker.dart';
import 'map_screen.dart';
import 'history_screen.dart';
import 'account_screen.dart'; // Ensure this import is correct

/// The main Dashboard widget with bottom navigation.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  /// List of pages for bottom navigation.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages
    _pages = [
      const HomeContentScreen(),
      const MapPage(),
      const HistoryPage(),
      const AccountPage(), // Ensure AccountPage does not require onLogout parameter
    ];
  }

  /// Log out method.
  Future<void> _logOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // After signing out, navigate to AuthChecker
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthChecker()),
      );
    } catch (e) {
      // Handle any error if sign-out fails
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  /// Dedicated method to update the current index.
  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: Colors.blue.shade700,
              elevation: 0,
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
        backgroundColor: Colors.white, // Set bottom nav bar color to white
        selectedItemColor: Colors.blueAccent, // Set selected item color to blueAccent
        unselectedItemColor: Colors.grey, // Set unselected item color to grey
        type: BottomNavigationBarType.fixed, // To show all labels
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

/// The main content for the Home tab without navigation buttons.
class HomeContentScreen extends StatelessWidget {
  const HomeContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardState = context.findAncestorStateOfType<_DashboardPageState>();

    return SafeArea(
      child: Container(
        width: double.infinity, // Full width
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.white],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),

            // Welcome Text
            Text(
              'LockGuard',
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Subtitle
            const Text(
              "Secure. Track. Lock.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Buttons to navigate to Map and History
            ElevatedButton(
              onPressed: () {
                if (dashboardState != null) {
                  // Change to Map tab
                  dashboardState._changePage(1);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
              ),
              child: const Text('Go to Map'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (dashboardState != null) {
                  // Change to History tab
                  dashboardState._changePage(2);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
              ),
              child: const Text('Go to History'),
            ),

            const Spacer(),

            // Bottom Padding
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0, right: 16, left: 16),
              child: Text(
                "Enjoy seamless tracking and security with LockGuard.",
                style: TextStyle(fontSize: 11, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
