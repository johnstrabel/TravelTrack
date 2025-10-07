// lib/services/country_polygons.dart
// Updated for Natural Earth GeoJSON format
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../data/countries.dart';

class CountryPolygons {
  CountryPolygons._(this._polygonsByCode);

  final Map<String, List<CountryPolygon>> _polygonsByCode;

  Map<String, List<CountryPolygon>> get polygonsByCode => _polygonsByCode;

  static Future<CountryPolygons> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? <dynamic>[];

    final Map<String, List<CountryPolygon>> byCode = {};
    int skippedCount = 0;

    for (final feature in features) {
      if (feature is! Map<String, dynamic>) continue;
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties == null) continue;

      final code = _extractIsoCode(properties);

      // Skip Antarctica unless we want to include it
      // Remove this check to include Antarctica
      if (code == null || code.isEmpty) {
        skippedCount++;
        continue;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) continue;

      final List<CountryPolygon> polygons = [];

      try {
        if (type == 'Polygon') {
          final rings = _ringsFromJson(coordinates);
          if (rings != null && rings.isNotEmpty) {
            polygons.add(CountryPolygon(rings.first, rings.skip(1).toList()));
          }
        } else if (type == 'MultiPolygon') {
          for (final polygon in coordinates) {
            if (polygon is! List) continue;
            final rings = _ringsFromJson(polygon);
            if (rings != null && rings.isNotEmpty) {
              polygons.add(CountryPolygon(rings.first, rings.skip(1).toList()));
            }
          }
        }
      } catch (e) {
        print('⚠️ Failed to parse polygon for $code: $e');
        continue;
      }

      if (polygons.isEmpty) continue;

      byCode.putIfAbsent(code, () => <CountryPolygon>[]).addAll(polygons);
    }

    print('✅ Loaded ${byCode.length} countries (skipped $skippedCount)');
    return CountryPolygons._(byCode);
  }

  String? findCountryCodeContaining(LatLng point) {
    try {
      for (final entry in _polygonsByCode.entries) {
        for (final polygon in entry.value) {
          if (polygon.contains(point)) {
            return entry.key;
          }
        }
      }
    } catch (e) {
      print('⚠️ Error in findCountryCodeContaining: $e');
      return null;
    }
    return null;
  }

  static String? _extractIsoCode(Map<String, dynamic> properties) {
    // Natural Earth uses these fields (in priority order)
    const isoKeys = [
      'ISO_A2', // Primary field in Natural Earth
      'iso_a2',
      'WB_A2', // World Bank code
      'ISO_A2_EH', // Extended codes
      'ADM0_A3', // 3-letter code (we'll convert)
      'ISO3166-1-Alpha-2',
      'ISO2',
      'ISO2_CODE',
    ];

    for (final key in isoKeys) {
      final value = properties[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty && trimmed != '-99' && trimmed != 'null') {
          // Convert to 2-letter code if needed
          if (trimmed.length == 2) {
            return trimmed.toUpperCase();
          }
        }
      }
    }

    // Fallback to name matching
    const nameKeys = ['ADMIN', 'NAME', 'name', 'NAME_LONG', 'SOVEREIGNT'];
    final nameToCode = _nameMap;
    for (final key in nameKeys) {
      final value = properties[key];
      if (value is String) {
        final trimmed = value.trim().toLowerCase();
        if (trimmed.isEmpty) continue;
        final fallback = nameToCode[trimmed];
        if (fallback != null && fallback.isNotEmpty) {
          return fallback;
        }
      }
    }

    return null;
  }

  static List<List<LatLng>>? _ringsFromJson(List<dynamic> jsonRings) {
    if (jsonRings.isEmpty) return null;

    final List<List<LatLng>> rings = [];
    for (final ring in jsonRings) {
      if (ring is! List) continue;
      final points = <LatLng>[];

      for (final coordinate in ring) {
        if (coordinate is! List || coordinate.length < 2) continue;

        try {
          final lon = (coordinate[0] as num).toDouble();
          final lat = (coordinate[1] as num).toDouble();

          // Validate coordinates
          if (lon.isNaN || lat.isNaN || lon.isInfinite || lat.isInfinite) {
            continue;
          }

          // Clamp to valid ranges
          if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            continue;
          }

          points.add(LatLng(lat, lon));
        } catch (e) {
          continue;
        }
      }

      // Need at least 4 points for a valid polygon (3 points + closing point)
      if (points.length >= 4) {
        rings.add(points);
      }
    }
    return rings.isEmpty ? null : rings;
  }

  static Map<String, String> get _nameMap {
    return _cachedNameMap ??= {
      for (final country in CountriesData.allCountries)
        country.name.toLowerCase(): country.code.toUpperCase(),
      // Add some common name variations
      'united states of america': 'US',
      'united kingdom': 'GB',
      'russia': 'RU',
      'south korea': 'KR',
      'north korea': 'KP',
      'czech republic': 'CZ',
      'democratic republic of the congo': 'CD',
      'republic of congo': 'CG',
    };
  }

  static Map<String, String>? _cachedNameMap;
}

class CountryPolygon {
  CountryPolygon(this.outer, this.holes) : _bbox = _BBox.fromRing(outer);

  final List<LatLng> outer;
  final List<List<LatLng>> holes;
  final _BBox _bbox;

  bool contains(LatLng point) {
    try {
      // Quick reject using bounding box
      if (!_bbox.contains(point)) return false;

      // Check if point is in outer ring
      if (!_pointInRing(point, outer)) return false;

      // Check if point is in any holes (if so, it's NOT in the polygon)
      for (final hole in holes) {
        if (_pointInRing(point, hole)) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static bool _pointInRing(LatLng point, List<LatLng> ring) {
    if (ring.length < 3) return false;

    var inside = false;

    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;

      final dy = yj - yi;

      // Skip near-horizontal edges
      if (dy.abs() < 1e-10) continue;

      // Ray casting algorithm
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / dy + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }
}

class _BBox {
  const _BBox(this.minLat, this.minLon, this.maxLat, this.maxLon);

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  bool contains(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLon &&
        point.longitude <= maxLon;
  }

  static _BBox fromRing(List<LatLng> ring) {
    if (ring.isEmpty) {
      return const _BBox(0, 0, 0, 0);
    }

    var minLat = ring[0].latitude;
    var maxLat = ring[0].latitude;
    var minLon = ring[0].longitude;
    var maxLon = ring[0].longitude;

    for (final point in ring.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return _BBox(minLat, minLon, maxLat, maxLon);
  }
}
