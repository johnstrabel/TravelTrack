// lib/services/trip_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';

/// Service for managing trips in Hive storage
class TripService {
  static const String _boxName = 'trips';
  static const String _tripCountryMapKey = 'trip_country_map';

  /// Get the trips box (opens if not already open)
  static Future<Box<dynamic>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Get all trips
  static Future<List<Trip>> getAllTrips() async {
    try {
      final box = await _getBox();
      final List<Trip> trips = [];

      for (final key in box.keys) {
        if (key == _tripCountryMapKey) continue; // Skip the map key
        final value = box.get(key);
        if (value is Map) {
          try {
            trips.add(Trip.fromJson(Map<String, dynamic>.from(value)));
          } catch (e) {
            print('⚠️ Error parsing trip $key: $e');
          }
        }
      }

      // Sort by start date (newest first), then by name
      trips.sort((a, b) {
        if (a.startDate != null && b.startDate != null) {
          return b.startDate!.compareTo(a.startDate!);
        }
        if (a.startDate != null) return -1;
        if (b.startDate != null) return 1;
        return a.name.compareTo(b.name);
      });

      return trips;
    } catch (e) {
      print('❌ Error getting all trips: $e');
      return [];
    }
  }

  /// Get a specific trip by ID
  static Future<Trip?> getTripById(String tripId) async {
    try {
      final box = await _getBox();
      final value = box.get(tripId);
      if (value is Map) {
        return Trip.fromJson(Map<String, dynamic>.from(value));
      }
      return null;
    } catch (e) {
      print('❌ Error getting trip $tripId: $e');
      return null;
    }
  }

  /// Create a new trip
  static Future<Trip> createTrip(Trip trip) async {
    try {
      final box = await _getBox();
      await box.put(trip.id, trip.toJson());

      // Update country-to-trip mapping for each country
      for (final countryCode in trip.countryCodes) {
        await _updateCountryTripMap(countryCode, trip.id);
      }

      print(
        '✅ Created trip: ${trip.name} with ${trip.countryCodes.length} countries',
      );
      return trip;
    } catch (e) {
      print('❌ Error creating trip: $e');
      rethrow;
    }
  }

  /// Update an existing trip
  static Future<void> updateTrip(Trip trip) async {
    try {
      final box = await _getBox();

      // Get old trip to compare countries
      final oldTrip = await getTripById(trip.id);

      // Update the trip
      await box.put(trip.id, trip.toJson());

      // Update country-to-trip mappings
      if (oldTrip != null) {
        // Remove old country mappings
        for (final code in oldTrip.countryCodes) {
          if (!trip.countryCodes.contains(code)) {
            await _removeCountryFromTripMap(code, trip.id);
          }
        }
      }

      // Add new country mappings
      for (final code in trip.countryCodes) {
        await _updateCountryTripMap(code, trip.id);
      }

      print('✅ Updated trip: ${trip.name}');
    } catch (e) {
      print('❌ Error updating trip: $e');
      rethrow;
    }
  }

  /// Delete a trip
  static Future<void> deleteTrip(String tripId) async {
    try {
      final box = await _getBox();
      final trip = await getTripById(tripId);

      if (trip != null) {
        // Remove all country mappings
        for (final code in trip.countryCodes) {
          await _removeCountryFromTripMap(code, tripId);
        }
      }

      await box.delete(tripId);
      print('✅ Deleted trip: $tripId');
    } catch (e) {
      print('❌ Error deleting trip: $e');
      rethrow;
    }
  }

  /// Assign a country to a trip
  static Future<void> assignCountryToTrip(
    String countryCode,
    String tripId,
  ) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        print('⚠️ Trip $tripId not found');
        return;
      }

      if (!trip.countryCodes.contains(countryCode)) {
        final updatedTrip = trip.copyWith(
          countryCodes: [...trip.countryCodes, countryCode],
        );
        await updateTrip(updatedTrip);
      }
    } catch (e) {
      print('❌ Error assigning country to trip: $e');
      rethrow;
    }
  }

  /// Remove a country from a trip
  static Future<void> removeCountryFromTrip(
    String countryCode,
    String tripId,
  ) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        print('⚠️ Trip $tripId not found');
        return;
      }

      final updatedCountries = trip.countryCodes
          .where((code) => code != countryCode)
          .toList();

      final updatedTrip = trip.copyWith(countryCodes: updatedCountries);
      await updateTrip(updatedTrip);
    } catch (e) {
      print('❌ Error removing country from trip: $e');
      rethrow;
    }
  }

  /// Get the trip ID for a specific country
  static Future<String?> getTripForCountry(String countryCode) async {
    try {
      final box = await _getBox();
      final map = box.get(_tripCountryMapKey) as Map?;
      if (map != null) {
        return map[countryCode] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting trip for country: $e');
      return null;
    }
  }

  /// Get all countries that have no trip assigned
  static Future<List<String>> getUnassignedCountries(
    List<String> visitedCountries,
  ) async {
    try {
      final box = await _getBox();
      final map = box.get(_tripCountryMapKey) as Map? ?? {};

      return visitedCountries.where((code) => !map.containsKey(code)).toList();
    } catch (e) {
      print('❌ Error getting unassigned countries: $e');
      return visitedCountries;
    }
  }

  /// Internal: Update the country-to-trip mapping
  static Future<void> _updateCountryTripMap(
    String countryCode,
    String tripId,
  ) async {
    try {
      final box = await _getBox();
      final map = Map<String, String>.from(
        (box.get(_tripCountryMapKey) as Map?) ?? {},
      );
      map[countryCode] = tripId;
      await box.put(_tripCountryMapKey, map);
    } catch (e) {
      print('❌ Error updating country trip map: $e');
    }
  }

  /// Internal: Remove a country from the trip mapping
  static Future<void> _removeCountryFromTripMap(
    String countryCode,
    String tripId,
  ) async {
    try {
      final box = await _getBox();
      final map = Map<String, String>.from(
        (box.get(_tripCountryMapKey) as Map?) ?? {},
      );

      // Only remove if it's mapped to this specific trip
      if (map[countryCode] == tripId) {
        map.remove(countryCode);
        await box.put(_tripCountryMapKey, map);
      }
    } catch (e) {
      print('❌ Error removing country from trip map: $e');
    }
  }

  /// Clear all trips (useful for testing/reset)
  static Future<void> clearAllTrips() async {
    try {
      final box = await _getBox();
      await box.clear();
      print('✅ Cleared all trips');
    } catch (e) {
      print('❌ Error clearing trips: $e');
    }
  }
}
