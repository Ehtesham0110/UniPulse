import 'package:flutter/material.dart';

class CollegeBranding {
  const CollegeBranding({
    required this.name,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String name;
  final String logoUrl;
  final Color primaryColor;
  final Color secondaryColor;

  factory CollegeBranding.unipulseDefault() {
    return const CollegeBranding(
      name: 'UniPulse',
      logoUrl: '',
      primaryColor: Color(0xFFFF6B1A),
      secondaryColor: Color(0xFFEC1E6C),
    );
  }
}
