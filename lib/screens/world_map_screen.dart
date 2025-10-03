import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../data/countries.dart';
import '../services/country_polygons.dart';
import '../models/country.dart';
import 'country_list_screen.dart';
import 'country_detail_screen.dart';
import 'profile_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with TickerProviderStateMixin {
  static const _visitedKey = 'codes';
  static const _flashDuration = Duration(milliseconds: 450);

  late final Box<dynamic> _visitedBox;
  Box<dynamic>? _profileBox;
  String? _profilePicturePath;
  CountryPolygons? _countryPolygons;
  bool _loadingPolygons = true;
  bool _isSelectMode = false;
  late AnimationController _fabAnimationController;
  late AnimationController _percentageController;
  late Animation<double> _percentageAnimation;

  String? _selectedContinent;

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
    _percentageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
    _loadProfilePicture();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _fabAnimationController.dispose();
    _percentageController.dispose();
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

      final visited = _readVisited(_visitedBox);
      final totalPct = visited.length / CountriesData.totalCount;
      _percentageAnimation = Tween<double>(begin: 0.0, end: totalPct).animate(
        CurvedAnimation(
          parent: _percentageController,
          curve: Curves.easeOutCubic,
        ),
      );
      _percentageController.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPolygons = false);
    }
  }

  Future<void> _loadProfilePicture() async {
    _profileBox = await Hive.openBox('profile_data');
    if (!mounted) return;
    setState(() {
      _profilePicturePath = _profileBox!.get('profilePicture') as String?;
    });
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
    final normalised = codes.map((code) => code.toUpperCase()).toList()..sort();
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

    _percentageController.reset();
    final totalPct = visited.length / CountriesData.totalCount;
    _percentageAnimation =
        Tween<double>(begin: _percentageAnimation.value, end: totalPct).animate(
          CurvedAnimation(
            parent: _percentageController,
            curve: Curves.easeOutCubic,
          ),
        );
    _percentageController.forward();
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

      _percentageController.reset();
      final totalPct = visited.length / CountriesData.totalCount;
      _percentageAnimation =
          Tween<double>(
            begin: _percentageAnimation.value,
            end: totalPct,
          ).animate(
            CurvedAnimation(
              parent: _percentageController,
              curve: Curves.easeOutCubic,
            ),
          );
      _percentageController.forward();

      final country = CountriesData.findByCode(code);
      if (!mounted || country == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${country.name} ${wasVisited ? 'removed' : 'added'}'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final country = CountriesData.findByCode(code);
      if (country == null) return;

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CountryDetailScreen(
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
    HapticFeedback.lightImpact();
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
      backgroundColor: const Color(0xFFB8D4E8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        toolbarHeight: 64,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                _loadProfilePicture();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF5B7C99), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFF5B7C99),
                    child: _profilePicturePath != null
                        ? Image.file(
                            File(_profilePicturePath!),
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeButton(
                label: 'View',
                icon: Icons.visibility_outlined,
                isSelected: !_isSelectMode,
                onTap: () {
                  if (_isSelectMode) _toggleMode();
                },
              ),
              _ModeButton(
                label: 'Select',
                icon: Icons.edit_outlined,
                isSelected: _isSelectMode,
                onTap: () {
                  if (!_isSelectMode) _toggleMode();
                },
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF5B7C99),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              tooltip: 'Country List',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CountryListScreen(onToggle: _toggleCountry),
                  ),
                );
                setState(() {});
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingPolygons
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
                  )
                : ValueListenableBuilder<Box<dynamic>>(
                    valueListenable: _visitedBox.listenable(
                      keys: const [_visitedKey],
                    ),
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
              return _GlassmorphicFooter(
                visitedCodes: visited,
                percentageAnimation: _percentageAnimation,
                selectedContinent: _selectedContinent,
                onContinentTap: (continent) {
                  setState(() {
                    if (_selectedContinent == continent) {
                      _selectedContinent = null;
                    } else {
                      _selectedContinent = continent;
                    }
                  });
                },
              );
            },
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

      final country = CountriesData.findByCode(code);
      final countryContinent = country?.continent;
      final isFiltered =
          _selectedContinent != null && countryContinent != _selectedContinent;

      Color fillColor;
      Color borderColor;

      if (isFiltered) {
        fillColor = const Color(0xFFF5F5F5).withOpacity(0.3);
        borderColor = const Color(0xFFE0E0E0).withOpacity(0.3);
      } else {
        fillColor = isVisited
            ? const Color(0xFF5B7C99)
            : isHover
            ? const Color(0xFF5B7C99).withOpacity(0.4)
            : const Color(0xFFEDE9E3);

        borderColor = isVisited
            ? const Color(0xFF4A6B7F)
            : isHover
            ? const Color(0xFF5B7C99)
            : const Color(0xFFD5CDC1);
      }

      for (final polygon in entry.value) {
        flutterPolygons.add(
          Polygon(
            points: polygon.outer,
            holePointsList: polygon.holes.isEmpty
                ? null
                : List.from(polygon.holes),
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: 0.8,
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
          flags:
              InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
          enableMultiFingerGestureRace: true,
        ),
        onTap: _handleTap,
        onPointerHover: _handleHover,
      ),
      children: [
        Container(color: const Color(0xFFB8D4E8)),
        PolygonLayer(polygons: flutterPolygons),
        if (_flashPoint != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: _flashPoint!,
                radius: 8,
                useRadiusInMeter: false,
                color: const Color(0xFF5B7C99).withOpacity(0.6),
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B7C99) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF2C3E50),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassmorphicFooter extends StatelessWidget {
  const _GlassmorphicFooter({
    required this.visitedCodes,
    required this.percentageAnimation,
    required this.selectedContinent,
    required this.onContinentTap,
  });

  final Set<String> visitedCodes;
  final Animation<double> percentageAnimation;
  final String? selectedContinent;
  final Function(String) onContinentTap;

  static const _continentColors = {
    'Africa': Color(0xFFFFF8F0),
    'Asia': Color(0xFFFFF0F0),
    'Europe': Color(0xFFF0F8FF),
    'North America': Color(0xFFF0FFF4),
    'South America': Color(0xFFFFF4F0),
    'Oceania': Color(0xFFF8F0FF),
  };

  @override
  Widget build(BuildContext context) {
    final continents = CountriesData.continents;
    final grouped = CountriesData.byContinent;
    final totalVisited = visitedCodes.length;
    final grandTotal = CountriesData.totalCount;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: percentageAnimation,
                  builder: (context, child) {
                    final displayPct = (percentageAnimation.value * 100)
                        .toStringAsFixed(0);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$displayPct%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B7C99),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'World Traveled',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$totalVisited / $grandTotal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: continents.map((continent) {
                    final countries = grouped[continent] ?? [];
                    final total = countries.length;
                    final visitedInContinent = countries
                        .where((c) => visitedCodes.contains(c.code))
                        .length;
                    return _ContinentChip(
                      label: continent,
                      visited: visitedInContinent,
                      total: total,
                      color: _continentColors[continent] ?? Colors.white,
                      isSelected: selectedContinent == continent,
                      onTap: () => onContinentTap(continent),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinentChip extends StatelessWidget {
  const _ContinentChip({
    required this.label,
    required this.visited,
    required this.total,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int visited;
  final int total;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : visited / total;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B7C99) : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B7C99) : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
