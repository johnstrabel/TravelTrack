// lib/models/country_status.dart

import 'package:flutter/material.dart';

/// Represents the relationship between a user and a country
enum CountryStatus {
  bucketlist, // Planning to visit (red)
  been, // Have visited (green)
  lived, // Lived there 6+ months (yellow)
}

extension CountryStatusExtension on CountryStatus {
  /// Display name for the status
  String get displayName {
    switch (this) {
      case CountryStatus.bucketlist:
        return 'Bucket List';
      case CountryStatus.been:
        return 'Been There';
      case CountryStatus.lived:
        return 'Lived There';
    }
  }

  /// Short label for buttons
  String get label {
    switch (this) {
      case CountryStatus.bucketlist:
        return 'Bucket List';
      case CountryStatus.been:
        return 'Been';
      case CountryStatus.lived:
        return 'Lived';
    }
  }

  /// Icon for the status
  IconData get icon {
    switch (this) {
      case CountryStatus.bucketlist:
        return Icons.favorite_border;
      case CountryStatus.been:
        return Icons.check_circle_outline;
      case CountryStatus.lived:
        return Icons.home_outlined;
    }
  }

  /// Color for the status on the map
  Color get mapColor {
    switch (this) {
      case CountryStatus.bucketlist:
        return const Color(0xFFE94B3C); // Red
      case CountryStatus.been:
        return const Color(0xFF7ED321); // Green
      case CountryStatus.lived:
        return const Color(0xFFF5A623); // Yellow/Orange
    }
  }

  /// Darker border color for the status
  Color get borderColor {
    switch (this) {
      case CountryStatus.bucketlist:
        return const Color(0xFFD43B2C);
      case CountryStatus.been:
        return const Color(0xFF6BC218);
      case CountryStatus.lived:
        return const Color(0xFFE69515);
    }
  }

  /// Convert to string for storage
  String toStorageString() {
    return name; // 'bucketlist', 'been', 'lived'
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
