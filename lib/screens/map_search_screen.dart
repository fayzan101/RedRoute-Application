import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  final TextEditingController _topSearchController = TextEditingController();
  final TextEditingController _mapSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set edge-to-edge mode to prevent navigation bar interference
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Set system UI colors to match the screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF181111),
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'People\'s Bus Service',
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
          
          // Top search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Icon(
                      Icons.search,
                      color: Color(0xFF886363),
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _topSearchController,
                      decoration: InputDecoration(
                        hintText: 'Where to?',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF886363),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(left: 8),
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF181111),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Map container
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDT-gPnEpUeSDV9sBuYGLRFlpC-Ggpon8b6-RpzuB_AHSgHlet8rdvBp75Bw4FElkJyh4h0Y31_I-fFYLL9Q4TjVKPSqxzK6Bl01UotLmUGlYxoFIP1uzVBlGSD2OJFqk1bxi4SZuZMVQsjn4neT0_Y9-7vMWzqVc-S6_FFjLjyuDFNdDBZ7FmOfl8AI4wk1tjeoS--OXuU6wv-oeYyOTCURgbIWnVDycmM4BLPPu8AuC6vA5VEttC6G_4s0jiErjrUpC43TZK3fTtD'
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Map search bar
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(
                              Icons.search,
                              color: Color(0xFF886363),
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _mapSearchController,
                              decoration: InputDecoration(
                                hintText: 'Search for a destination',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF886363),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.only(left: 8),
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF181111),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Map controls
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        children: [
                          // Zoom controls
                          Column(
                            children: [
                              _buildMapControlButton(
                                icon: Icons.add,
                                isTop: true,
                                onTap: () {},
                              ),
                              _buildMapControlButton(
                                icon: Icons.remove,
                                isTop: false,
                                onTap: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Location button
                          _buildMapControlButton(
                            icon: Icons.navigation,
                            isTop: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Location button
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                height: 56,
                constraints: const BoxConstraints(maxWidth: 480),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE92929),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 24),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required bool isTop,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop ? 8 : 0),
            topRight: Radius.circular(isTop ? 8 : 0),
            bottomLeft: Radius.circular(!isTop ? 8 : 0),
            bottomRight: Radius.circular(!isTop ? 8 : 0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF181111),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF4F0F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.home,
                    label: 'Home',
                    isActive: true,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.map_outlined,
                    label: 'Routes',
                    isActive: false,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.bookmark_outline,
                    label: 'Favorites',
                    isActive: false,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    isActive: false,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          Container(height: 20, color: Colors.white), // Bottom safe area
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? const Color(0xFF181111) : const Color(0xFF886363),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? const Color(0xFF181111) : const Color(0xFF886363),
              letterSpacing: 0.015,
            ),
          ),
        ],
      ),
    );
  }
} 