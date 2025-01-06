import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_checker.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  // Log out method
  Future<void> _logOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // After signing out, navigate to AuthChecker (or any login screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthChecker()), // Replace with your login checker page
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final creationDate = user?.metadata.creationTime != null
        ? DateFormat('dd MMM yyyy').format(user!.metadata.creationTime!)
        : 'N/A';

    return Scaffold(
      backgroundColor: Colors.blue[50],  // Light blue background
      appBar: AppBar(
  title: Text(
    "Account",
    style: GoogleFonts.poppins(
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  backgroundColor: Colors.blue[700], 
  centerTitle: true, // Darker blue for contrast
),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile Icon with shadow effect
                Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue[700],
                    child: Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Personalized greeting with a clean, modern font
                Text(
                  'Hi, ${user?.email?.split('@')[0] ?? 'Guest'}!',
                  style: GoogleFonts.lato(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 10),

                // Display user's email
                Text(
                  'Your Email: ${user?.email ?? 'Not Logged In'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),

                // Account Information Card with modern design
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Information:',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Email:',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                              Flexible(
                                child: Text(
                                  user?.email ?? 'N/A',
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Account Created:',
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                              Flexible(
                                child: Text(
                                  creationDate,
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Sign-out Button with gradient effect
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GestureDetector(
                    onTap: () => _logOut(context), // Using the logOut function
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}