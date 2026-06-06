import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/custom_widgets.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              OneTapLogo(
                size: 120,
                showSubtitle: true,
              ),
              SizedBox(height: 60),
              CircularProgressIndicator(
                color: AppColors.accentOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
