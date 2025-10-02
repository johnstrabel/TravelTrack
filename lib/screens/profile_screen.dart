import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../data/countries.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Box<dynamic> _profileBox;
  late final Box<dynamic> _visitedBox;
  
  String _username = '';
  String _bio = '';
  String? _profilePicturePath;
  bool _isLoading = true;
  bool _isEditingUsername = false;
  bool _isEditingBio = false;
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _profileBox = await Hive.openBox('profile_data');
    _visitedBox = Hive.box('visited_countries');
    
    setState(() {
      _username = _profileBox.get('username', defaultValue: 'traveler') as String;
      _bio = _profileBox.get('bio', defaultValue: '') as String;
      _profilePicturePath = _profileBox.get('profilePicture') as String?;
      _usernameController.text = _username;
      _bioController.text = _bio;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    await _profileBox.put('username', _username);
    await _profileBox.put('bio', _bio);
    if (_profilePicturePath != null) {
      await _profileBox.put('profilePicture', _profilePicturePath);
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          setState(() {
            _profilePicturePath = filePath;
          });
          await _saveProfile();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Set<String> _getVisitedCountries() {
    final raw = _visitedBox.get('codes');
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  Map<String, int> _getContinentCounts() {
    final visited = _getVisitedCountries();
    final counts = <String, int>{};
    
    for (final code in visited) {
      final country = CountriesData.findByCode(code);
      if (country != null) {
        counts[country.continent] = (counts[country.continent] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  String? _getLastVisitedCountry() {
    // For now, just return the first country in the list
    // In the future, we could track actual visit dates
    final visited = _getVisitedCountries();
    if (visited.isEmpty) return null;
    
    final code = visited.first;
    final country = CountriesData.findByCode(code);
    return country?.name;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF5B7C99),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5B7C99),
          ),
        ),
      );
    }

    final visited = _getVisitedCountries();
    final totalCountries = CountriesData.totalCount;
    final percentage = ((visited.length / totalCountries) * 100).toStringAsFixed(1);
    final continentCounts = _getContinentCounts();
    final continentsVisited = continentCounts.keys.length;
    final lastVisited = _getLastVisitedCountry();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF5B7C99),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF5B7C99),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _pickProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profilePicturePath != null
                                ? Image.file(
                                    File(_profilePicturePath!),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Color(0xFF5B7C99),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Color(0xFF5B7C99),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Username
                  _isEditingUsername
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _usernameController,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                autofocus: true,
                                onSubmitted: (_) {
                                  setState(() {
                                    _username = _usernameController.text.trim();
                                    if (_username.isEmpty) {
                                      _username = 'traveler';
                                      _usernameController.text = _username;
                                    }
                                    _isEditingUsername = false;
                                  });
                                  _saveProfile();
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _username = _usernameController.text.trim();
                                  if (_username.isEmpty) {
                                    _username = 'traveler';
                                    _usernameController.text = _username;
                                  }
                                  _isEditingUsername = false;
                                });
                                _saveProfile();
                              },
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingUsername = true;
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '@$_username',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 8),
                  
                  // Bio
                  _isEditingBio
                      ? Column(
                          children: [
                            TextField(
                              controller: _bioController,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              maxLength: 100,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.all(12),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Add a short bio...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              autofocus: true,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _bioController.text = _bio;
                                      _isEditingBio = false;
                                    });
                                  },
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _bio = _bioController.text.trim();
                                      _isEditingBio = false;
                                    });
                                    _saveProfile();
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingBio = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _bio.isEmpty ? 'Add a bio...' : _bio,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _bio.isEmpty
                                          ? Colors.white60
                                          : Colors.white,
                                      fontStyle: _bio.isEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Stats Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_rounded, color: Color(0xFF5B7C99)),
                      SizedBox(width: 8),
                      Text(
                        'Travel Stats',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Main Stats Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              value: '${visited.length}',
                              label: 'Countries',
                              icon: Icons.flag_rounded,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            _StatItem(
                              value: '$percentage%',
                              label: 'World',
                              icon: Icons.public_rounded,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            _StatItem(
                              value: '$continentsVisited',
                              label: 'Continents',
                              icon: Icons.map_rounded,
                            ),
                          ],
                        ),
                        if (lastVisited != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F8FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF5B7C99),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Last Added',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastVisited,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Continent Breakdown
                  const Row(
                    children: [
                      Icon(Icons.travel_explore_rounded, color: Color(0xFF5B7C99)),
                      SizedBox(width: 8),
                      Text(
                        'By Continent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ...CountriesData.continents.map((continent) {
                    final count = continentCounts[continent] ?? 0;
                    final total = CountriesData.byContinent[continent]?.length ?? 0;
                    final pct = total > 0 ? (count / total) : 0.0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
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
                              Text(
                                continent,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              Text(
                                '$count / $total',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF5B7C99),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF5B7C99),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}