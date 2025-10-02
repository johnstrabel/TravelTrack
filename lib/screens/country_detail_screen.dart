import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';

class CountryDetailScreen extends StatefulWidget {
  final String countryCode;
  final String countryName;

  const CountryDetailScreen({
    super.key,
    required this.countryCode,
    required this.countryName,
  });

  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  late final Box<dynamic> _dataBox;
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  List<String> _photos = [];
  List<String> _cities = [];
  int _rating = 0;
  DateTime? _visitedDate;
  bool _isLoading = true;
  Timer? _autoSaveTimer;

  static const Map<String, String> _flagEmojis = {
    'US': '🇺🇸', 'CA': '🇨🇦', 'MX': '🇲🇽', 'BR': '🇧🇷', 'AR': '🇦🇷',
    'GB': '🇬🇧', 'FR': '🇫🇷', 'DE': '🇩🇪', 'IT': '🇮🇹', 'ES': '🇪🇸',
    'CN': '🇨🇳', 'JP': '🇯🇵', 'IN': '🇮🇳', 'AU': '🇦🇺', 'RU': '🇷🇺',
    'ZA': '🇿🇦', 'EG': '🇪🇬', 'NG': '🇳🇬', 'KE': '🇰🇪', 'MA': '🇲🇦',
    'CZ': '🇨🇿', 'PL': '🇵🇱', 'NL': '🇳🇱', 'SE': '🇸🇪', 'NO': '🇳🇴',
    'DK': '🇩🇰', 'FI': '🇫🇮', 'PT': '🇵🇹', 'GR': '🇬🇷', 'TR': '🇹🇷',
    'TH': '🇹🇭', 'VN': '🇻🇳', 'ID': '🇮🇩', 'MY': '🇲🇾', 'SG': '🇸🇬',
    'PH': '🇵🇭', 'KR': '🇰🇷', 'NZ': '🇳🇿', 'CL': '🇨🇱', 'CO': '🇨🇴',
    'PE': '🇵🇪', 'VE': '🇻🇪', 'UA': '🇺🇦', 'RO': '🇷🇴', 'HU': '🇭🇺',
    'AT': '🇦🇹', 'CH': '🇨🇭', 'BE': '🇧🇪', 'IE': '🇮🇪', 'CR': '🇨🇷',
  };

  static const Map<String, Color> _continentColors = {
    'Africa': Color(0xFFFFF8F0),
    'Asia': Color(0xFFFFF0F0),
    'Europe': Color(0xFFF0F8FF),
    'North America': Color(0xFFF0FFF4),
    'South America': Color(0xFFFFF4F0),
    'Oceania': Color(0xFFF8F0FF),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _journalController.addListener(_onJournalChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _journalController.removeListener(_onJournalChanged);
    _journalController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onJournalChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveDataSilently();
    });
  }

  Future<void> _loadData() async {
    _dataBox = await Hive.openBox('country_data');
    final countryData = _dataBox.get(widget.countryCode) as Map?;
    
    if (countryData != null) {
      _journalController.text = countryData['journal'] as String? ?? '';
      _photos = List<String>.from(countryData['photos'] as List? ?? []);
      _cities = List<String>.from(countryData['cities'] as List? ?? []);
      _rating = countryData['rating'] as int? ?? 0;
      
      final dateString = countryData['visitedDate'] as String?;
      if (dateString != null) {
        _visitedDate = DateTime.tryParse(dateString);
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    await _saveDataSilently();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('${widget.countryName} saved!'),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF5B7C99),
      ),
    );
  }

  Future<void> _saveDataSilently() async {
    final data = {
      'journal': _journalController.text,
      'photos': _photos,
      'cities': _cities,
      'rating': _rating,
      'visitedDate': _visitedDate?.toIso8601String(),
    };
    
    await _dataBox.put(widget.countryCode, data);
  }

  Future<void> _addPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          setState(() {
            _photos.add(filePath);
          });
          await _saveDataSilently();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding photo: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _photos.removeAt(index);
              });
              _saveDataSilently();
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewPhoto(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(path)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5B7C99),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _visitedDate = picked;
      });
      _saveDataSilently();
    }
  }

  void _setRating(int rating) {
    setState(() {
      _rating = rating;
    });
    _saveDataSilently();
  }

  String _getContinent() {
    final code = widget.countryCode;
    if (['DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD', 'KM', 'CG', 'CD', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW', 'CI', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW'].contains(code)) {
      return 'Africa';
    } else if (['AF', 'AM', 'AZ', 'BH', 'BD', 'BT', 'BN', 'KH', 'CN', 'CY', 'GE', 'IN', 'ID', 'IR', 'IQ', 'IL', 'JP', 'JO', 'KZ', 'KW', 'KG', 'LA', 'LB', 'MY', 'MV', 'MN', 'MM', 'NP', 'KP', 'OM', 'PK', 'PS', 'PH', 'QA', 'RU', 'SA', 'SG', 'KR', 'LK', 'SY', 'TW', 'TJ', 'TH', 'TL', 'TR', 'TM', 'AE', 'UZ', 'VN', 'YE'].contains(code)) {
      return 'Asia';
    } else if (['AL', 'AD', 'AT', 'BY', 'BE', 'BA', 'BG', 'HR', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IS', 'IE', 'IT', 'XK', 'LV', 'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME', 'NL', 'MK', 'NO', 'PL', 'PT', 'RO', 'SM', 'RS', 'SK', 'SI', 'ES', 'SE', 'CH', 'UA', 'GB', 'VA'].contains(code)) {
      return 'Europe';
    } else if (['AG', 'BS', 'BB', 'BZ', 'CA', 'CR', 'CU', 'DM', 'DO', 'SV', 'GD', 'GT', 'HT', 'HN', 'JM', 'MX', 'NI', 'PA', 'KN', 'LC', 'VC', 'TT', 'US'].contains(code)) {
      return 'North America';
    } else if (['AR', 'BO', 'BR', 'CL', 'CO', 'EC', 'GY', 'PY', 'PE', 'SR', 'UY', 'VE'].contains(code)) {
      return 'South America';
    } else {
      return 'Oceania';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.countryName),
          backgroundColor: const Color(0xFF5B7C99),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5B7C99),
          ),
        ),
      );
    }

    final flag = _flagEmojis[widget.countryCode] ?? '🏳️';
    final continent = _getContinent();
    final headerColor = _continentColors[continent] ?? const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.countryName),
        backgroundColor: const Color(0xFF5B7C99),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _saveData,
            tooltip: 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: headerColor,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        flag,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.countryName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.countryCode,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickStatCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'First Visit',
                      value: _visitedDate != null
                          ? '${_visitedDate!.month}/${_visitedDate!.year}'
                          : 'Not set',
                      onTap: _pickDate,
                    ),
                    const SizedBox(width: 12),
                    _QuickStatCard(
                      icon: Icons.star_rounded,
                      label: 'Rating',
                      value: _rating > 0 ? '$_rating/5' : 'Not rated',
                      onTap: () => _showRatingDialog(),
                    ),
                    const SizedBox(width: 12),
                    _QuickStatCard(
                      icon: Icons.location_city_rounded,
                      label: 'Cities',
                      value: _cities.isEmpty ? 'None' : '${_cities.length}',
                      onTap: () => _showCitiesDialog(),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.article_rounded,
                    title: 'Journal Entry',
                  ),
                  const SizedBox(height: 12),
                  Container(
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
                    child: TextField(
                      controller: _journalController,
                      maxLines: 10,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What was your favorite moment in ${widget.countryName}?',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF5B7C99),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'Auto-saves as you type',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _SectionHeader(
                    icon: Icons.photo_library_rounded,
                    title: 'Photos',
                    action: TextButton.icon(
                      onPressed: _addPhoto,
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                      label: const Text('Add Photo'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5B7C99),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_photos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_camera_rounded,
                              size: 56,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No photos yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add photos to remember your journey',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _viewPhoto(_photos[index]),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_photos[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate your experience'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starRating = index + 1;
                return IconButton(
                  icon: Icon(
                    starRating <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFF5B7C99),
                    size: 36,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      _setRating(starRating);
                    });
                  },
                );
              }),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCitiesDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Cities Visited'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            hintText: 'Add a city',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            if (_cityController.text.trim().isNotEmpty) {
                              setState(() {
                                _cities.add(_cityController.text.trim());
                                _cityController.clear();
                              });
                              setDialogState(() {});
                              _saveDataSilently();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (_cityController.text.trim().isNotEmpty) {
                            setState(() {
                              _cities.add(_cityController.text.trim());
                              _cityController.clear();
                            });
                            setDialogState(() {});
                            _saveDataSilently();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_cities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No cities added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cities.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(entry.value),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _cities.removeAt(entry.key);
                            });
                            setDialogState(() {});
                            _saveDataSilently();
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
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
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF5B7C99),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF5B7C99)),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        if (action != null) action!,
      ],
    );
  }
}