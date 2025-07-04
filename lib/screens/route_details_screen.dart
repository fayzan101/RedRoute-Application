import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
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
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From your location section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'From your location',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF181111),
                        letterSpacing: -0.015,
                      ),
                    ),
                  ),
                  
                  // Transport options
                  _buildTransportOption(
                    icon: Icons.directions_walk,
                    title: 'Walk to Stop 1',
                    subtitle: '10 min walk',
                  ),
                  _buildTransportOption(
                    icon: Icons.motorcycle,
                    title: 'Bykea to Stop 1',
                    subtitle: '15 min Bykea',
                  ),
                  _buildTransportOption(
                    icon: Icons.directions_car,
                    title: 'Rickshaw to Stop 1',
                    subtitle: '20 min Rickshaw',
                  ),
                  
                  // Bus Route section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Bus Route',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF181111),
                        letterSpacing: -0.015,
                      ),
                    ),
                  ),
                  
                  // Route map
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCSjyp0vpv_vOvUNUjhfGPMXmwtxe4JsVHPxVI9CvMthpOxCZynmMBsO-xuocOTIak83Q7fhc7r6pefobcyE_CGjbKpHj7ozVRml7h32KVvLUuZm-f4Tl4qnShFn7Jbpg5vAzYW5_vwmJEDaE9OVoM6nM3QVklU5K7K2sUafRQaKYdWNZ7PomHujkcAH0dq2qfTxN_nmW0aFx9hLCmw39q7W7vEbJYHCuInh5eNtELedopuvcMqD96WlCpdeihNx_OpXADUTdKhuOFW'
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                  // Bus stops list
                  ..._buildStopsList(),
                ],
              ),
            ),
          ),
          
          // Fare estimate button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE92929),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Fare Estimate: PKR 50',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.015,
                  ),
                ),
              ),
            ),
          ),
          
          Container(height: 20, color: Colors.white), // Bottom safe area
        ],
      ),
    );
  }

  Widget _buildTransportOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF181111),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF181111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF886363),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStopsList() {
    final stops = [
      'Stop 1', 'Stop 2', 'Stop 3', 'Stop 4', 'Stop 5',
      'Stop 6', 'Stop 7', 'Stop 8', 'Stop 9', 'Stop 10'
    ];
    
    return stops.map((stop) => _buildStopItem(stop)).toList();
  }

  Widget _buildStopItem(String stopName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stopName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: const Color(0xFF181111),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} 