import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart'; // Temporarily disabled

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _titleController;
  late AnimationController _subtitleController;
  
  late Animation<double> _iconSlideAnimation;
  late Animation<double> _iconOpacityAnimation;
  late Animation<double> _titleSlideAnimation;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _subtitleOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set full-screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Set system UI colors for splash screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Initialize animation controllers
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Icon animations (slide down)
    _iconSlideAnimation = Tween<double>(
      begin: -30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOut,
    ));
    
    _iconOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOut,
    ));
    
    // Title animations (fade in up)
    _titleSlideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));
    
    _titleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));
    
    // Subtitle animation (fade in)
    _subtitleOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOut,
    ));
    
    _startAnimations();
  }

  void _startAnimations() async {
    // Start icon animation immediately
    _iconController.forward();
    
    // Start title animation after 400ms
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _titleController.forward();
    
    // Start subtitle animation after 800ms total
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _subtitleController.forward();
    
    // Navigate to welcome screen after total 3 seconds
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  @override
  void dispose() {
    // Restore system UI when leaving splash screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _iconController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE53E3E), // RedRoute red color
      body: Semantics(
        label: 'RedRoute App Loading Screen',
        hint: 'Karachi Bus Navigation App is starting up',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Bus Icon with Semantics
              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _iconSlideAnimation.value),
                    child: Opacity(
                      opacity: _iconOpacityAnimation.value,
                      child: Semantics(
                        label: 'Bus Icon',
                        hint: 'RedRoute bus navigation icon',
                        child: Container(
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.directions_bus,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // Animated Title with Semantics
              AnimatedBuilder(
                animation: _titleController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _titleSlideAnimation.value),
                    child: Opacity(
                      opacity: _titleOpacityAnimation.value,
                      child: Semantics(
                        label: 'RedRoute',
                        hint: 'App name and title',
                        child: const Text(
                          'RedRoute',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'serif', // Using system font instead
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 10),
              
              // Animated Subtitle with Semantics
              AnimatedBuilder(
                animation: _subtitleController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _subtitleOpacityAnimation.value,
                    child: Semantics(
                      label: 'Near your destination',
                      hint: 'App tagline and description',
                      child: const Text(
                        'Near your destination.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'serif', // Using system font instead
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Loading indicator with Semantics
              const SizedBox(height: 40),
              Semantics(
                label: 'Loading indicator',
                hint: 'App is loading, please wait',
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 