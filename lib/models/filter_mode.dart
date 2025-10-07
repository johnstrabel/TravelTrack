// lib/models/filter_mode.dart

/// Represents the different map view modes
enum FilterMode {
  visited, // Default: Shows Been + Lived (counts toward %)
  trips, // Color by trip
  years, // Color by year visited
  bucketList, // Shows bucket list only (red, doesn't count)
}

extension FilterModeExtension on FilterMode {
  /// Display name for the filter
  String get displayName {
    switch (this) {
      case FilterMode.visited:
        return 'Countries Visited';
      case FilterMode.trips:
        return 'By Trip';
      case FilterMode.years:
        return 'By Year';
      case FilterMode.bucketList:
        return 'Bucket List';
    }
  }

  /// Short label for buttons
  String get label {
    switch (this) {
      case FilterMode.visited:
        return 'Visited';
      case FilterMode.trips:
        return 'Trips';
      case FilterMode.years:
        return 'Years';
      case FilterMode.bucketList:
        return 'Bucket List';
    }
  }

  /// Icon for the filter mode
  String get emoji {
    switch (this) {
      case FilterMode.visited:
        return '✅';
      case FilterMode.trips:
        return '✈️';
      case FilterMode.years:
        return '📅';
      case FilterMode.bucketList:
        return '🔴';
    }
  }

  /// Description text
  String get description {
    switch (this) {
      case FilterMode.visited:
        return 'Countries you\'ve been to or lived in';
      case FilterMode.trips:
        return 'Group countries by trip';
      case FilterMode.years:
        return 'Color by year visited';
      case FilterMode.bucketList:
        return 'Countries you want to visit';
    }
  }
}
