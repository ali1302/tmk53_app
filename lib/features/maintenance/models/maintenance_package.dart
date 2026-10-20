import 'package:flutter/material.dart';

class MaintenancePackage {
  const MaintenancePackage({
    required this.title,
    required this.priceKd,
    required this.icon,
    required this.accent,
    required this.description,
  });

  final String title;
  final int priceKd;
  final IconData icon;
  final Color accent;
  final String description;
}
