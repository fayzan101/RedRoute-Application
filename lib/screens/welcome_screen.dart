import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with bus icon and RedRoute title
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF181111),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Text(
                    'RedRoute',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF181111),
                      letterSpacing: -0.015,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the layout
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Welcome title
                  Text(
                    'Welcome to RedRoute',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF181111),
                      height: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    'Your journey through Karachi starts here. Get ready to explore the city with ease and comfort.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: const Color(0xFF181111),
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Progress bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DCDC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.2, // 20% progress
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF181111),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53E3E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
          

        ],
      ),
    );
  }


} 