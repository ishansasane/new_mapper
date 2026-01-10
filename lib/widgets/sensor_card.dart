import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SensorStatusCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool isActive;
  final String? statusText;

  const SensorStatusCard({
    super.key,
    required this.icon,
    required this.name,
    required this.isActive,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.green : Colors.red,
          size: 30,
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: statusText != null
            ? Text(
                statusText!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isActive ? Colors.green : Colors.red,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'ACTIVE' : 'INACTIVE',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
