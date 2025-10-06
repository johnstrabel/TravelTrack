// lib/screens/world_map_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/countries.dart';
import '../services/country_polygons.dart';
import '../models/country.dart';
import 'country_list_screen.dart';
import 'country_detail_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Hive keys
  static const _visitedKey = 'codes';

  // UI timings
  static const _flashDuration = Duration(milliseconds: 450);

  // Map & data
  final MapController _mapController = MapController();
  late final Box<dynamic> _visitedBox;
  Box<dynamic>? _profileBox;
  CountryPolygons? _countryPolygons;

  // Avatar
  String? _profilePicturePath;

  // Loading flags
  bool _loadingPolygons = true;

  // Modes & filters
  bool _isSelectMode = false;
  String? _selectedContinent;

  // Hover / flash
  String? _hoverCode;
  LatLng? _flashPoint;
  Timer? _flashTimer;

  // Animations
  late final AnimationController _fabAnimationController;
  late final AnimationController _percentageController;
  late Animation<double> _percentageAnimation;

  // Drawer key for opening programmatically
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map bounds & start
  static const _initialCenter = LatLng(22, 0.0);
  static final LatLngBounds _worldBounds = LatLngBounds(
    const LatLng(-58, -180),
    const LatLng(84, 180),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Animations
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _percentageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Safe default to avoid late-init nulls before polygons load
    _percentageAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _percentageController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Hive init
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
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _fabAnimationController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  // Keep avatar fresh when returning to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadProfilePicture();
    }
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
      _percentageController
        ..reset()
        ..forward();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading polygons: $e');
      if (!mounted) return;
      setState(() => _loadingPolygons = false);
    }
  }

  Future<void> _loadProfilePicture() async {
    try {
      _profileBox ??= await Hive.openBox('user_profile');

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // Try fresh from Supabase first
      if (userId != null) {
        final profile = await supabase
            .from('users')
            .select('profile_pic_url')
            .eq('id', userId)
            .maybeSingle();

        final url = (profile?['profile_pic_url'] as String?);
        if (url != null && url.isNotEmpty) {
          // ignore: avoid_print
          print('📸 Loaded profile pic URL (remote): $url');
          if (!mounted) return;
          setState(() => _profilePicturePath = url);
          await _profileBox?.put('profile_pic_url', url);
          return;
        }
      }

      // Fall back to cached
      final cachedUrl = _profileBox?.get('profile_pic_url') as String?;
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        // ignore: avoid_print
        print('📸 Using cached profile pic URL');
        if (!mounted) return;
        setState(() => _profilePicturePath = cachedUrl);
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading profile picture: $e');
    }
  }

  // ---------- Visited persistence helpers ----------
  Set<String> _readVisited(Box<dynamic> box) {
    final raw = box.get(_visitedKey);
    if (raw is List) {
      return raw.whereType<String>().map((c) => c.toUpperCase()).toSet();
    }
    if (raw is Set) {
      return raw.cast<String>().map((c) => c.toUpperCase()).toSet();
    }
    return <String>{};
  }

  void _writeVisited(Set<String> codes) {
    final normalized = codes.map((c) => c.toUpperCase()).toList()..sort();
    _visitedBox.put(_visitedKey, normalized);
  }

  void _toggleCountry(String code) {
    final visited = _readVisited(_visitedBox);
    final wasVisited = visited.contains(code);
    if (wasVisited) {
      visited.remove(code);
    } else {
      visited.add(code);
    }
    _writeVisited(visited);

    // Animate percentage from current value to new value
    final newPct = visited.length / CountriesData.totalCount;
    _percentageController.reset();
    _percentageAnimation =
        Tween<double>(begin: _percentageAnimation.value, end: newPct).animate(
          CurvedAnimation(
            parent: _percentageController,
            curve: Curves.easeOutCubic,
          ),
        );
    _percentageController.forward();

    // Optional hook: sync single toggle to cloud (upsert/delete)
    // await DataSyncService.syncCountryToggle(code, wasVisited ? 'remove' : 'add');
  }

  // ---------- Map interactions ----------
  void _handleTap(TapPosition position, LatLng latLng) {
    final polys = _countryPolygons;
    if (polys == null) return;

    final code = polys.findCountryCodeContaining(latLng);
    if (code == null) return;

    if (_isSelectMode) {
      _triggerFlash(latLng);
      _toggleCountry(code);

      final country = CountriesData.findByCode(code);
      if (!mounted || country == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${country.name} ${_readVisited(_visitedBox).contains(code) ? 'added' : 'removed'}',
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
    final polys = _countryPolygons;
    if (polys == null) return;
    final code = polys.findCountryCodeContaining(latLng);
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

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                        ? (_profilePicturePath!.startsWith('http')
                              ? Image.network(
                                  _profilePicturePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  loadingBuilder: (context, child, prog) {
                                    if (prog == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(_profilePicturePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ))
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
              icon: const Icon(Icons.menu, color: Colors.white),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildMenuDrawer(),
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

  Widget _buildMenuDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B7C99), Color(0xFF4A6B7F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.travel_explore,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),

              _DrawerMenuItem(
                icon: Icons.people,
                title: 'Friends',
                subtitle: 'Manage your connections',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  );
                },
              ),
              _DrawerMenuItem(
                icon: Icons.list_rounded,
                title: 'Country List',
                subtitle: 'Browse all countries',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CountryListScreen(onToggle: _toggleCountry),
                    ),
                  );
                },
              ),
              _DrawerMenuItem(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Account & preferences',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Travel Tracker v1.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(Set<String> visited) {
    final polygons = _countryPolygons;
    if (polygons == null) return const SizedBox.shrink();

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

    return MouseRegion(
      onHover: (evt) {
        if (evt is PointerHoverEvent) {
          final pos = evt.localPosition;
          // Convert hover screen pos to LatLng via map; FlutterMap exposes pointer -> latlng via handlers
          // but we already use onPointerHover in options. Keep this wrapper for web/desktop hovers.
        }
      },
      onExit: _handleHoverExit,
      child: FlutterMap(
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
      ),
    );
  }
}

// ------------------ Drawer Menu Item ------------------
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ Mode Button ------------------
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

// ------------------ Footer ------------------
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
                  builder: (context, _) {
                    final pct = percentageAnimation.value * 100;
                    return Text(
                      '${pct.toStringAsFixed(1)}% World Traveled · $totalVisited / $grandTotal',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
