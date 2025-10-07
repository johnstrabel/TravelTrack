// lib/models/country_status.dart

import 'package:flutter/material.dart';

/// Represents the relationship between a user and a country
enum CountryStatus {
  want,   // Planning to visit (red)
  been,   // Have visited (green)
  lived,  // Lived there temporarily (yellow)
  live,   // Currently living there (blue)
}

extension CountryStatusExtension on CountryStatus {
  /// Display name for the status
  String get displayName {
    switch (this) {
      case CountryStatus.want:
        return 'Want to Visit';
      case CountryStatus.been:
        return 'Been';
      case CountryStatus.lived:
        return 'Lived';
      case CountryStatus.live:
        return 'Live';
    }
  }

  /// Short label for buttons
  String get label {
    switch (this) {
      case CountryStatus.want:
        return 'Want';
      case CountryStatus.been:
        return 'Been';
      case CountryStatus.lived:
        return 'Lived';
      case CountryStatus.live:
        return 'Live';
    }
  }

  /// Icon for the status
  IconData get icon {
    switch (this) {
      case CountryStatus.want:
        return Icons.favorite_border;
      case CountryStatus.been:
        return Icons.check_circle_outline;
      case CountryStatus.lived:
        return Icons.home_outlined;
      case CountryStatus.live:
        return Icons.location_on;
    }
  }

  /// Color for the status on the map
  Color get mapColor {
    switch (this) {
      case CountryStatus.want:
        return const Color(0xFFE94B3C); // Red
      case CountryStatus.been:
        return const Color(0xFF7ED321); // Green
      case CountryStatus.lived:
        return const Color(0xFFF5A623); // Yellow/Orange
      case CountryStatus.live:
        return const Color(0xFF4A90E2); // Blue
    }
  }

  /// Darker border color for the status
  Color get borderColor {
    switch (this) {
      case CountryStatus.want:
        return const Color(0xFFD43B2C);
      case CountryStatus.been:
        return const Color(0xFF6BC218);
      case CountryStatus.lived:
        return const Color(0xFFE69515);
      case CountryStatus.live:
        return const Color(0xFF3A7BC8);
    }
  }

  /// Convert to string for storage
  String toStorageString() {
    return name; // 'want', 'been', 'lived', 'live'
  }

  /// Parse from storage string
  static CountryStatus? fromString(String? value) {
    if (value == null) return null;
    try {
      return CountryStatus.values.firstWhere(
        (status) => status.name == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}