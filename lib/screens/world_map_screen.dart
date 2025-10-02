import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../data/countries.dart';
import '../services/country_polygons.dart';
import '../models/country.dart';
import 'country_list_screen.dart';
import 'country_detail_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> with SingleTickerProviderStateMixin {
  static const _visitedKey = 'codes';
  static const _flashDuration = Duration(milliseconds: 450);

  late final Box<dynamic> _visitedBox;
  CountryPolygons? _countryPolygons;
  bool _loadingPolygons = true;
  bool _isSelectMode = false;
  late AnimationController _fabAnimationController;

  final MapController _mapController = MapController();
  String? _hoverCode;
  LatLng? _flashPoint;
  Timer? _flashTimer;

  static const _initialCenter = LatLng(22, 0.0);
  static final LatLngBounds _worldBounds = LatLngBounds(
    const LatLng(-58, -180),
    const LatLng(84, 180),
  );

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _visitedBox = Hive.box('visited_countries');
    if (!_visitedBox.containsKey(_visitedKey)) {
      _visitedBox.put(_visitedKey, <String>[]);
    } else {
      final existing = _visitedBox.get(_visitedKey);
      if (existing is Set) {
        _visitedBox.put(_visitedKey, existing.cast<String>().toList());
      }
    }
    _loadPolygons();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPolygons() async {
    try {
      final polygons = await CountryPolygons.loadFromAsset(
        'assets/geo/world_countries_simplified.geojson',
      );
      if (!mounted) return;
      setState(() {
        _countryPolygons = polygons;
        _loadingPolygons = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPolygons = false);
    }
  }

  Set<String> _readVisited(Box<dynamic> box) {
    final raw = box.get(_visitedKey);
    if (raw is List) {
      return raw.whereType<String>().map((code) => code.toUpperCase()).toSet();
    }
    if (raw is Set) {
      return raw.cast<String>().map((code) => code.toUpperCase()).toSet();
    }
    return <String>{};
  }

  void _writeVisited(Set<String> codes) {
    final normalised = codes.map((code) => code.toUpperCase()).toList()
      ..sort();
    _visitedBox.put(_visitedKey, normalised);
  }

  void _toggleCountry(String code) {
    final visited = _readVisited(_visitedBox);
    if (visited.contains(code)) {
      visited.remove(code);
    } else {
      visited.add(code);
    }
    _writeVisited(visited);
  }

  void _handleTap(TapPosition position, LatLng latLng) {
    if (_countryPolygons == null) return;

    final code = _countryPolygons!.findCountryCodeContaining(latLng);
    if (code == null) return;

    if (_isSelectMode) {
      _triggerFlash(latLng);
      
      final visited = _readVisited(_visitedBox);
      final wasVisited = visited.contains(code);
      if (wasVisited) {
        visited.remove(code);
      } else {
        visited.add(code);
      }
      _writeVisited(visited);

      final country = CountriesData.findByCode(code);
      if (!mounted || country == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${country.name} ${wasVisited ? 'removed' : 'added'}',
          ),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final country = CountriesData.findByCode(code);
      if (country == null) return;
      
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => CountryDetailScreen(
            countryCode: country.code,
            countryName: country.name,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _triggerFlash(LatLng point) {
    _flashTimer?.cancel();
    setState(() => _flashPoint = point);
    _flashTimer = Timer(_flashDuration, () {
      if (!mounted) return;
      setState(() => _flashPoint = null);
    });
  }

  void _handleHover(PointerHoverEvent event, LatLng latLng) {
    if (_countryPolygons == null) return;
    final code = _countryPolygons!.findCountryCodeContaining(latLng);
    if (code != _hoverCode) {
      setState(() => _hoverCode = code);
    }
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (_hoverCode != null) {
      setState(() => _hoverCode = null);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (_isSelectMode) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        title: const Text(
          'Travel Tracker',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isSelectMode 
                    ? const Color(0xFF4E79A7).withOpacity(0.15)
                    : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isSelectMode 
                      ? const Color(0xFF4E79A7) 
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSelectMode ? Icons.edit : Icons.visibility,
                    size: 16,
                    color: _isSelectMode 
                        ? const Color(0xFF4E79A7) 
                        : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSelectMode ? 'Select' : 'View',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isSelectMode 
                          ? const Color(0xFF4E79A7) 
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.menu, color: Colors.grey.shade700),
            tooltip: 'Menu',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CountryListScreen(onToggle: _toggleCountry),
                ),
              );
              setState(() {});
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _loadingPolygons
                    ? const Center(child: CircularProgressIndicator())
                    : ValueListenableBuilder<Box<dynamic>>(
                        valueListenable:
                            _visitedBox.listenable(keys: const [_visitedKey]),
                        builder: (context, box, _) {
                          final visited = _readVisited(box);
                          return _buildMap(visited);
                        },
                      ),
              ),
              ValueListenableBuilder<Box<dynamic>>(
                valueListenable: _visitedBox.listenable(keys: const [_visitedKey]),
                builder: (context, box, _) {
                  final visited = _readVisited(box);
                  return _FooterStats(visitedCodes: visited);
                },
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 180,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: FloatingActionButton(
                onPressed: _toggleMode,
                backgroundColor: _isSelectMode ? Colors.green : const Color(0xFF4E79A7),
                tooltip: _isSelectMode ? 'Switch to View Mode' : 'Switch to Select Mode',
                elevation: 6,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: Tween(begin: 0.0, end: 1.0).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    _isSelectMode ? Icons.check : Icons.add,
                    key: ValueKey(_isSelectMode),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(Set<String> visited) {
    final polygons = _countryPolygons;
    if (polygons == null) {
      return const SizedBox.shrink();
    }

    final flutterPolygons = <Polygon>[];
    for (final entry in polygons.polygonsByCode.entries) {
      final code = entry.key;
      final isVisited = visited.contains(code);
      final isHover = _hoverCode == code && !isVisited;

      final fillColor = isVisited
          ? const Color(0xFF4E79A7)
          : isHover
              ? const Color(0xFF4E79A7).withOpacity(0.4)
              : Colors.grey.shade300.withOpacity(0.9);
      final borderColor = isVisited
          ? const Color(0xFF375A7F)
          : isHover
              ? const Color(0xFF4E79A7)
              : Colors.grey.shade400;

      for (final polygon in entry.value) {
        flutterPolygons.add(
          Polygon(
            points: polygon.outer,
            holePointsList:
                polygon.holes.isEmpty ? null : List.from(polygon.holes),
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: 0.7,
            isFilled: true,
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: 2.3,
        minZoom: 1.6,
        maxZoom: 10,
        cameraConstraint: CameraConstraint.contain(bounds: _worldBounds),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
        onTap: _handleTap,
        onPointerHover: _handleHover,
      ),
      children: [
        // Solid ocean background instead of tiles
        Container(
          color: const Color(0xFFB8D4E8),
        ),
        PolygonLayer(polygons: flutterPolygons),
        if (_flashPoint != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _flashPoint!,
                radius: 6,
                useRadiusInMeter: false,
                color: const Color(0xFF4E79A7).withOpacity(0.85),
                borderColor: Colors.white,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
      ],
    );
  }
}

class _FooterStats extends StatelessWidget {
  const _FooterStats({required this.visitedCodes});

  final Set<String> visitedCodes;

  @override
  Widget build(BuildContext context) {
    final continents = CountriesData.continents;
    final grouped = CountriesData.byContinent;

    final totalVisited = visitedCodes.length;
    final grandTotal = CountriesData.totalCount;
    final totalPct = grandTotal == 0 ? 0.0 : totalVisited / grandTotal;

    final cards = <Widget>[];
    for (final continent in continents) {
      final countries = grouped[continent] ?? <Country>[];
      final total = countries.length;
      final visitedInContinent =
          countries.where((c) => visitedCodes.contains(c.code)).length;
      cards.add(
        _ContinentCard(
          label: continent,
          visited: visitedInContinent,
          total: total,
        ),
      );
    }

    cards.add(
      _TotalPill(
        visited: totalVisited,
        total: grandTotal,
        pct: totalPct,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: cards,
        ),
      ),
    );
  }
}

class _ContinentCard extends StatelessWidget {
  const _ContinentCard({
    required this.label,
    required this.visited,
    required this.total,
  });

  final String label;
  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : visited / total;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                pctLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF4E79A7),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$visited / $total',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({
    required this.visited,
    required this.total,
    required this.pct,
  });

  final int visited;
  final int total;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFF4E79A7).withOpacity(0.03),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: const Color(0xFF4E79A7).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E79A7).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${(pct * 100).toStringAsFixed(0)}%  |  $visited / $total',
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C3E50),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}