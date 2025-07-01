import 'package:flutter/material.dart';
import '../models/stop.dart';

class StopMarker extends StatelessWidget {
  final Stop stop;
  final bool isSelected;
  final VoidCallback? onTap;

  const StopMarker({
    super.key,
    required this.stop,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isSelected ? 60 : 40,
        height: isSelected ? 60 : 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_bus,
          color: Colors.white,
          size: isSelected ? 24 : 16,
        ),
      ),
    );
  }
}

class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.my_location,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

class DestinationMarker extends StatelessWidget {
  const DestinationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.place,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
