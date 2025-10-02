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

    print('DEBUG: Total features in GeoJSON: ${features.length}');

    final Map<String, List<CountryPolygon>> byCode = {};
    int successfullyParsed = 0;
    int skippedNoCode = 0;
    int skippedNoGeometry = 0;

    for (final feature in features) {
      if (feature is! Map<String, dynamic>) continue;
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties == null) continue;

      final code = _extractIsoCode(properties);
      if (code == null || code.isEmpty || code == 'AQ') {
        skippedNoCode++;
        continue;
      }

      final geometry = feature['geometry'];
      if (geometry is! Map<String, dynamic>) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) continue;

      final List<CountryPolygon> polygons = [];
      if (type == 'Polygon') {
        final rings = _ringsFromJson(coordinates);
        if (rings != null) {
          polygons.add(CountryPolygon(rings.first, rings.skip(1).toList()));
        }
      } else if (type == 'MultiPolygon') {
        for (final polygon in coordinates) {
          if (polygon is! List) continue;
          final rings = _ringsFromJson(polygon);
          if (rings != null) {
            polygons.add(CountryPolygon(rings.first, rings.skip(1).toList()));
          }
        }
      }

      if (polygons.isEmpty) {
        skippedNoGeometry++;
        if (code == 'US' || code == 'TZ' || code == 'GL') {
          print('WARNING: Country $code has NO polygons! Type: $type, Coordinates structure issue');
        }
        continue;
      }

      byCode.putIfAbsent(code, () => <CountryPolygon>[]).addAll(polygons);
      successfullyParsed++;

      if (code == 'US' || code == 'TZ' || code == 'GL') {
        print('✓ Successfully loaded $code with ${polygons.length} polygon(s)');
      }
    }

    print('DEBUG: Successfully parsed: $successfullyParsed countries');
    print('DEBUG: Skipped (no code): $skippedNoCode');
    print('DEBUG: Skipped (no geometry): $skippedNoGeometry');
    print('DEBUG: Total countries in map: ${byCode.length}');
    
    final testCodes = ['US', 'TZ', 'GL', 'BR', 'CN'];
    print('DEBUG: Test countries present:');
    for (final code in testCodes) {
      print('  - $code: ${byCode.containsKey(code) ? "YES (${byCode[code]!.length} polygons)" : "NO"}');
    }

    return CountryPolygons._(byCode);
  }

  String? findCountryCodeContaining(LatLng point) {
    for (final entry in _polygonsByCode.entries) {
      for (final polygon in entry.value) {
        if (polygon.contains(point)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String? _extractIsoCode(Map<String, dynamic> properties) {
    const isoKeys = [
      'ISO3166-1-Alpha-2',
      'ISO_A2',
      'iso_a2',
      'ISO2',
      'ISO_A2_EH',
      'WB_A2',
      'ISO2_CODE',
    ];
    for (final key in isoKeys) {
      final value = properties[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty && trimmed != '-99') {
          return trimmed.toUpperCase();
        }
      }
    }

    const nameKeys = ['ADMIN', 'NAME', 'name', 'SOVEREIGNT'];
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
        final lon = (coordinate[0] as num).toDouble();
        final lat = (coordinate[1] as num).toDouble();
        points.add(LatLng(lat, lon));
      }
      if (points.length >= 3) {
        rings.add(points);
      }
    }
    return rings.isEmpty ? null : rings;
  }

  static Map<String, String> get _nameMap {
    return _cachedNameMap ??= {
      for (final country in CountriesData.allCountries)
        country.name.toLowerCase(): country.code.toUpperCase(),
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
    if (!_bbox.contains(point)) return false;
    if (!_pointInRing(point, outer)) return false;
    for (final hole in holes) {
      if (_pointInRing(point, hole)) return false;
    }
    return true;
  }

  static bool _pointInRing(LatLng point, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;

      final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      
      if (intersects) inside = !inside;
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
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLon = double.infinity;
    var maxLon = -double.infinity;

    for (final point in ring) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return _BBox(minLat, minLon, maxLat, maxLon);
  }
}