// lib/models/trip.dart
import 'package:flutter/material.dart';

/// Represents a travel trip with multiple countries
class Trip {
  final String id; // UUID
  final String name; // "Euro Trip 2024"
  final int colorValue; // Color.value for storage
  final List<String> countryCodes; // ['FR', 'DE', 'IT']
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;

  Trip({
    required this.id,
    required this.name,
    required this.colorValue,
    this.countryCodes = const [],
    this.startDate,
    this.endDate,
    this.description,
  });

  // Get Color object from stored value
  Color get color => Color(colorValue);

  // Create Trip with Color object
  factory Trip.withColor({
    required String id,
    required String name,
    required Color color,
    List<String> countryCodes = const [],
    DateTime? startDate,
    DateTime? endDate,
    String? description,
  }) {
    return Trip(
      id: id,
      name: name,
      colorValue: color.value,
      countryCodes: countryCodes,
      startDate: startDate,
      endDate: endDate,
      description: description,
    );
  }

  // Serialization for Hive storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'countryCodes': countryCodes,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'description': description,
    };
  }

  // Deserialization from Hive storage
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      countryCodes:
          (json['countryCodes'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      description: json['description'] as String?,
    );
  }

  // Create a copy with modified fields
  Trip copyWith({
    String? id,
    String? name,
    int? colorValue,
    List<String>? countryCodes,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      countryCodes: countryCodes ?? this.countryCodes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'Trip(id: $id, name: $name, countries: ${countryCodes.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Trip && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined trip colors for user selection
class TripColors {
  static const List<Color> palette = [
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  static Color get random {
    return palette[(DateTime.now().millisecondsSinceEpoch % palette.length)];
  }
}
