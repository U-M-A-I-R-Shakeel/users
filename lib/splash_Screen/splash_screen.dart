import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:users/Assistants/assistant_methods.dart';
import 'package:users/global/global.dart';
import 'package:users/screens/login_screen.dart';
import 'package:users/screens/pending_approval_screen.dart';
import 'package:users/screens/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  startTimer(){
    Timer(const Duration(seconds: 4), () async {
      if(firebaseAuth.currentUser != null) {
        AssistantMethods.readCurrentOnLineUserInfo();

        // Check user approval status
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(firebaseAuth.currentUser!.uid);
        DatabaseEvent event = await userRef.once();

        if (!mounted) return;

        if (event.snapshot.value != null) {
          Map userData = event.snapshot.value as Map;
          String status = userData["status"]?.toString() ?? "approved";

          if (status == "approved") {
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (c) => const RoleSelectionScreen()), (route) => false);
          } else if (status == "pending") {
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (c) => const PendingApprovalScreen()), (route) => false);
          } else {
            // rejected or unknown
            firebaseAuth.signOut();
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (c) => const LoginScreen()), (route) => false);
          }
        } else {
          // Legacy user without status field
          Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (c) => const RoleSelectionScreen()), (route) => false);
        }
      }
      else{
        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (c) => const LoginScreen()), (route) => false);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();

    startTimer();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'images/logo.png',
                  width: 200,
                  height: 200,
                ),
                const SizedBox(height: 30),
                const Text(
                  'University Ride\nSharing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your Premium Ride',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
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
