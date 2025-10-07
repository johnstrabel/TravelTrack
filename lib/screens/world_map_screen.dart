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
import '../models/country_status.dart';
import '../models/filter_mode.dart';
import '../widgets/country_status_modal.dart';
import '../widgets/filter_sheet.dart';
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
  static const _statusKey = 'country_status';

  // UI timings
  static const _flashDuration = Duration(milliseconds: 450);
  static const _autoHideDuration = Duration(seconds: 1);

  // Map & data
  final MapController _mapController = MapController();
  late final Box<dynamic> _visitedBox;
  Box<dynamic>? _profileBox;
  CountryPolygons? _countryPolygons;

  // Avatar
  String? _profilePicturePath;

  // Loading flags
  bool _loadingPolygons = true;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Country> _searchResults = [];
  bool _showSearchResults = false;

  // Modes & filters
  bool _isSelectMode = false;
  FilterMode _filterMode = FilterMode.visited;

  // Auto-hide UI
  bool _showTopBar = true;
  bool _showLegend = true;
  Timer? _uiHideTimer;

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

  @override
  void initState() {
    super.initState();
    print('🗺️🗺️🗺️ WORLD_MAP: initState called 🗺️🗺️🗺️');
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

    // Search listener
    _searchController.addListener(_onSearchChanged);

    _loadPolygons();
    _loadProfilePicture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _uiHideTimer?.cancel();
    _fabAnimationController.dispose();
    _percentageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

      if (userId != null) {
        final profile = await supabase
            .from('users')
            .select('profile_pic_url')
            .eq('id', userId)
            .maybeSingle();

        final url = (profile?['profile_pic_url'] as String?);
        if (url != null && url.isNotEmpty) {
          print('📸 Loaded profile pic URL (remote): $url');
          if (!mounted) return;
          setState(() => _profilePicturePath = url);
          await _profileBox?.put('profile_pic_url', url);
          return;
        }
      }

      final cachedUrl = _profileBox?.get('profile_pic_url') as String?;
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        print('📸 Using cached profile pic URL');
        if (!mounted) return;
        setState(() => _profilePicturePath = cachedUrl);
      }
    } catch (e) {
      print('❌ Error loading profile picture: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    final results = CountriesData.allCountries
        .where(
          (country) =>
              country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query),
        )
        .take(10)
        .toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
    });
  }

  void _quickAddCountry(String code) {
    HapticFeedback.lightImpact();
    _toggleCountry(code);
    final country = CountriesData.findByCode(code);
    if (country != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${country.name} marked as visited'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => _toggleCountry(code),
          ),
        ),
      );
    }
  }

  void _onMapInteraction() {
    _uiHideTimer?.cancel();

    setState(() {
      _showTopBar = false;
      _showLegend = false;
    });

    _uiHideTimer = Timer(_autoHideDuration, () {
      if (!mounted) return;
      setState(() {
        _showTopBar = true;
        _showLegend = true;
      });
    });
  }

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

  Map<String, String> _readStatuses(Box<dynamic> box) {
    final raw = box.get(_statusKey);
    if (raw is Map) {
      return Map<String, String>.from(raw);
    }
    return {};
  }

  void _writeStatuses(Map<String, String> statuses) {
    _visitedBox.put(_statusKey, statuses);
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
  }

  void _handleTap(TapPosition position, LatLng latLng) {
    final polys = _countryPolygons;
    if (polys == null) return;

    final code = polys.findCountryCodeContaining(latLng);
    if (code == null) return;

    final country = CountriesData.findByCode(code);
    if (country == null) return;

    HapticFeedback.lightImpact();

    if (_isSelectMode) {
      _triggerFlash(latLng);
      _toggleCountry(code);

      if (!mounted) return;
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
      _showCountryStatusModal(country);
    }
  }

  void _showCountryStatusModal(Country country) {
    final statuses = _readStatuses(_visitedBox);
    final statusString = statuses[country.code];

    CountryStatus? currentStatus;
    if (statusString != null) {
      try {
        currentStatus = CountryStatus.values.firstWhere(
          (s) => s.name == statusString,
        );
      } catch (_) {
        currentStatus = null;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CountryStatusModal(
        countryCode: country.code,
        countryName: country.name,
        currentStatus: currentStatus,
        onStatusSelected: (status) {
          HapticFeedback.mediumImpact();
          _handleStatusSelection(country.code, status);
        },
        onViewDetails: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CountryDetailScreen(
                countryCode: country.code,
                countryName: country.name,
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleStatusSelection(String countryCode, CountryStatus? status) {
    final statuses = _readStatuses(_visitedBox);
    final visited = _readVisited(_visitedBox);

    if (status == null) {
      // Remove status completely
      statuses.remove(countryCode);
      visited.remove(countryCode);
    } else {
      // Set the status
      statuses[countryCode] = status.name;

      // CRITICAL: Only add to visited list if it's 'been' or 'lived' (NOT bucketlist)
      if (status == CountryStatus.been || status == CountryStatus.lived) {
        if (!visited.contains(countryCode)) {
          visited.add(countryCode);
        }
      } else {
        // If changing to bucketlist, remove from visited count
        visited.remove(countryCode);
      }
    }

    _writeStatuses(statuses);
    _writeVisited(visited);

    // Recalculate percentage based ONLY on visited (been + lived)
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

    if (mounted) {
      final country = CountriesData.findByCode(countryCode);
      final statusText = status == null
          ? 'Status removed'
          : '${_getStatusLabel(status)} selected';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${country?.name}: $statusText'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getStatusLabel(CountryStatus status) {
    switch (status) {
      case CountryStatus.bucketlist:
        return 'Bucket List';
      case CountryStatus.been:
        return 'Been There';
      case CountryStatus.lived:
        return 'Lived There';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFB8D4E8),
      body: GestureDetector(
        onTap: () {
          if (_showSearchResults) {
            setState(() => _showSearchResults = false);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: _loadingPolygons
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5B7C99),
                      ),
                    )
                  : ValueListenableBuilder<Box<dynamic>>(
                      valueListenable: _visitedBox.listenable(
                        keys: const [_visitedKey, _statusKey],
                      ),
                      builder: (context, box, _) {
                        final visited = _readVisited(box);
                        return _buildMap(visited);
                      },
                    ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _showTopBar ? 0 : -100,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            if (_showSearchResults)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 16,
                right: 16,
                child: _buildSearchResults(),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _showLegend ? 16 : -80,
              left: 0,
              right: 0,
              child: _buildLegend(),
            ),
          ],
        ),
      ),
      endDrawer: _buildMenuDrawer(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white.withOpacity(0.0)],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
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
                      : const Icon(Icons.person, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search or tap map...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF5B7C99),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _clearSearch,
                          color: Colors.grey[400],
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onTap: () {
                  setState(() => _showSearchResults = true);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
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
              icon: const Icon(Icons.tune, color: Colors.white, size: 20),
              tooltip: 'Filter',
              onPressed: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => FilterSheet(
                    currentMode: _filterMode,
                    onModeSelected: (mode) {
                      setState(() => _filterMode = mode);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
              icon: const Icon(Icons.menu, color: Colors.white, size: 20),
              tooltip: 'Menu',
              onPressed: () {
                HapticFeedback.lightImpact();
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No countries found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final country = _searchResults[index];
                final isVisited = _readVisited(
                  _visitedBox,
                ).contains(country.code);

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isVisited
                          ? const Color(0xFF5B7C99)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        CountriesData.getFlagEmoji(country.code),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  title: Text(
                    country.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    country.code,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isVisited)
                        TextButton(
                          onPressed: () {
                            _quickAddCountry(country.code);
                            _clearSearch();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            backgroundColor: const Color(0xFF5B7C99),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    _clearSearch();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CountryDetailScreen(
                          countryCode: country.code,
                          countryName: country.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: const Color(0xFF7ED321), label: 'Been'),
            const SizedBox(width: 12),
            _LegendItem(color: const Color(0xFFF5A623), label: 'Lived'),
            const SizedBox(width: 12),
            _LegendItem(color: const Color(0xFFE94B3C), label: 'Bucket'),
          ],
        ),
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
              ValueListenableBuilder<Box<dynamic>>(
                valueListenable: _visitedBox.listenable(
                  keys: const [_visitedKey, _statusKey],
                ),
                builder: (context, box, _) {
                  final visited = _readVisited(box);
                  final statuses = _readStatuses(box);

                  // Count bucket list countries separately
                  int bucketListCount = 0;
                  for (final entry in statuses.entries) {
                    if (entry.value == 'bucketlist') {
                      bucketListCount++;
                    }
                  }

                  final total = CountriesData.totalCount;
                  final pct = (visited.length / total * 100).toStringAsFixed(1);

                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _filterMode == FilterMode.bucketList
                              ? 'Bucket List Countries'
                              : '$pct% World Traveled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _filterMode == FilterMode.bucketList
                              ? '$bucketListCount countries'
                              : '${visited.length} / $total countries',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16),
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

    final statuses = _readStatuses(_visitedBox);
    final flutterPolygons = <Polygon>[];

    for (final entry in polygons.polygonsByCode.entries) {
      final code = entry.key;
      final statusString = statuses[code];
      final isHover = _hoverCode == code;

      // Determine if country should be shown based on filter mode
      bool shouldShow = false;
      Color fillColor = const Color(0xFFE0E0E0);
      Color borderColor = const Color(0xFFBDBDBD);

      // Parse status
      CountryStatus? status;
      if (statusString != null) {
        try {
          status = CountryStatus.values.firstWhere(
            (s) => s.name == statusString,
          );
        } catch (_) {
          status = null;
        }
      }

      // Apply filter logic
      switch (_filterMode) {
        case FilterMode.visited:
          // Show only 'been' and 'lived' countries
          if (status == CountryStatus.been || status == CountryStatus.lived) {
            shouldShow = true;
            if (status == CountryStatus.lived) {
              fillColor = const Color(0xFFF5A623); // Yellow for lived
              borderColor = const Color(0xFFE69515);
            } else {
              fillColor = const Color(0xFF7ED321); // Green for been
              borderColor = const Color(0xFF6BC218);
            }
          }
          break;

        case FilterMode.trips:
          // TODO: Implement trip coloring in Phase 3B
          // For now, show all visited countries in blue
          if (status == CountryStatus.been || status == CountryStatus.lived) {
            shouldShow = true;
            fillColor = const Color(0xFF5B7C99);
            borderColor = const Color(0xFF4A6A85);
          }
          break;

        case FilterMode.years:
          // TODO: Implement year coloring in Phase 3C
          // For now, show all visited countries in purple
          if (status == CountryStatus.been || status == CountryStatus.lived) {
            shouldShow = true;
            fillColor = const Color(0xFF9C27B0);
            borderColor = const Color(0xFF7B1FA2);
          }
          break;

        case FilterMode.bucketList:
          // Show ONLY bucket list countries in red
          if (status == CountryStatus.bucketlist) {
            shouldShow = true;
            fillColor = const Color(0xFFE94B3C); // Red
            borderColor = const Color(0xFFD43B2C);
          }
          break;
      }

      // Skip if shouldn't show
      if (!shouldShow) continue;

      // Apply hover effect
      if (isHover) {
        fillColor = fillColor.withOpacity(0.7);
      }

      // Create polygons for this country
      for (final polygon in entry.value) {
        flutterPolygons.add(
          Polygon(
            points: polygon.outer,
            holePointsList: polygon.holes.isEmpty
                ? null
                : List.from(polygon.holes),
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: 0.6,
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
        minZoom: 1.5,
        maxZoom: 8,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(84, 180)),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
          rotationThreshold: 20.0,
          pinchZoomThreshold: 0.5,
          pinchMoveThreshold: 40.0,
          scrollWheelVelocity: 0.005,
        ),
        onTap: _handleTap,
        keepAlive: true,
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[400]!, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }
}
