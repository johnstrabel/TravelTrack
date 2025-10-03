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

  // Category controllers
  final TextEditingController _mustSeesController = TextEditingController();
  final TextEditingController _hiddenGemsController = TextEditingController();
  final TextEditingController _restaurantsController = TextEditingController();
  final TextEditingController _barsController = TextEditingController();

  final TextEditingController _cityController = TextEditingController();

  // Photos with captions
  List<Map<String, String>> _photosWithCaptions = [];

  List<String> _cities = [];
  int _rating = 0;
  DateTime? _visitedDate;

  // Daily journal entries: [{date: "2025-01-15", text: "..."}]
  List<Map<String, String>> _dailyEntries = [];

  bool _isLoading = true;
  Timer? _autoSaveTimer;

  static const Map<String, String> _flagEmojis = {
    'US': '🇺🇸',
    'CA': '🇨🇦',
    'MX': '🇲🇽',
    'BR': '🇧🇷',
    'AR': '🇦🇷',
    'GB': '🇬🇧',
    'FR': '🇫🇷',
    'DE': '🇩🇪',
    'IT': '🇮🇹',
    'ES': '🇪🇸',
    'CN': '🇨🇳',
    'JP': '🇯🇵',
    'IN': '🇮🇳',
    'AU': '🇦🇺',
    'RU': '🇷🇺',
    'ZA': '🇿🇦',
    'EG': '🇪🇬',
    'NG': '🇳🇬',
    'KE': '🇰🇪',
    'MA': '🇲🇦',
    'CZ': '🇨🇿',
    'PL': '🇵🇱',
    'NL': '🇳🇱',
    'SE': '🇸🇪',
    'NO': '🇳🇴',
    'DK': '🇩🇰',
    'FI': '🇫🇮',
    'PT': '🇵🇹',
    'GR': '🇬🇷',
    'TR': '🇹🇷',
    'TH': '🇹🇭',
    'VN': '🇻🇳',
    'ID': '🇮🇩',
    'MY': '🇲🇾',
    'SG': '🇸🇬',
    'PH': '🇵🇭',
    'KR': '🇰🇷',
    'NZ': '🇳🇿',
    'CL': '🇨🇱',
    'CO': '🇨🇴',
    'PE': '🇵🇪',
    'VE': '🇻🇪',
    'UA': '🇺🇦',
    'RO': '🇷🇴',
    'HU': '🇭🇺',
    'AT': '🇦🇹',
    'CH': '🇨🇭',
    'BE': '🇧🇪',
    'IE': '🇮🇪',
    'CR': '🇨🇷',
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
    _mustSeesController.addListener(_onTextChanged);
    _hiddenGemsController.addListener(_onTextChanged);
    _restaurantsController.addListener(_onTextChanged);
    _barsController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _mustSeesController.dispose();
    _hiddenGemsController.dispose();
    _restaurantsController.dispose();
    _barsController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveDataSilently();
    });
  }

  Future<void> _loadData() async {
    _dataBox = await Hive.openBox('country_data');
    final countryData = _dataBox.get(widget.countryCode) as Map?;

    if (countryData != null) {
      _mustSeesController.text = countryData['mustSees'] as String? ?? '';
      _hiddenGemsController.text = countryData['hiddenGems'] as String? ?? '';
      _restaurantsController.text = countryData['restaurants'] as String? ?? '';
      _barsController.text = countryData['bars'] as String? ?? '';

      // Load photos with captions
      final photosList = countryData['photos'] as List?;
      if (photosList != null) {
        _photosWithCaptions = photosList.map((item) {
          if (item is Map) {
            return {
              'path': item['path'] as String? ?? '',
              'caption': item['caption'] as String? ?? '',
            };
          } else if (item is String) {
            // Migration from old format
            return {'path': item, 'caption': ''};
          }
          return {'path': '', 'caption': ''};
        }).toList();
      }

      _cities = List<String>.from(countryData['cities'] as List? ?? []);
      _rating = countryData['rating'] as int? ?? 0;

      final dateString = countryData['visitedDate'] as String?;
      if (dateString != null) {
        _visitedDate = DateTime.tryParse(dateString);
      }

      // Load daily entries
      final entriesList = countryData['dailyEntries'] as List?;
      if (entriesList != null) {
        _dailyEntries = entriesList
            .map((item) {
              if (item is Map) {
                return {
                  'date': item['date'] as String? ?? '',
                  'text': item['text'] as String? ?? '',
                };
              }
              return {'date': '', 'text': ''};
            })
            .where((e) => e['date']!.isNotEmpty)
            .toList();
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
      'mustSees': _mustSeesController.text,
      'hiddenGems': _hiddenGemsController.text,
      'restaurants': _restaurantsController.text,
      'bars': _barsController.text,
      'photos': _photosWithCaptions,
      'cities': _cities,
      'rating': _rating,
      'visitedDate': _visitedDate?.toIso8601String(),
      'dailyEntries': _dailyEntries,
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
            _photosWithCaptions.add({'path': filePath, 'caption': ''});
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

  void _editPhotoCaption(int index) {
    final captionController = TextEditingController(
      text: _photosWithCaptions[index]['caption'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Caption'),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(
            hintText: 'What\'s happening here?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _photosWithCaptions[index]['caption'] = captionController.text;
              });
              _saveDataSilently();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                _photosWithCaptions.removeAt(index);
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

  void _viewPhoto(int index) {
    final photo = _photosWithCaptions[index];
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
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _editPhotoCaption(index);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    child: Image.file(File(photo['path']!)),
                  ),
                ),
              ),
              if (photo['caption']!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black.withOpacity(0.7),
                  child: Text(
                    photo['caption']!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _reorderPhotos() {
    showDialog(
      context: context,
      builder: (context) => _PhotoReorderDialog(
        photos: _photosWithCaptions,
        onReorder: (newOrder) {
          setState(() {
            _photosWithCaptions = newOrder;
          });
          _saveDataSilently();
        },
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF5B7C99)),
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

  void _addDailyEntry() {
    final textController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Daily Journal Entry'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF5B7C99),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText:
                        'What happened today? Any funny stories or memorable moments?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  setState(() {
                    _dailyEntries.add({
                      'date': selectedDate.toIso8601String().split('T')[0],
                      'text': textController.text.trim(),
                    });
                    _dailyEntries.sort(
                      (a, b) => b['date']!.compareTo(a['date']!),
                    );
                  });
                  _saveDataSilently();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _editDailyEntry(int index) {
    final entry = _dailyEntries[index];
    final textController = TextEditingController(text: entry['text']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Entry - ${_formatDate(entry['date']!)}'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 6,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _dailyEntries.removeAt(index);
              });
              _saveDataSilently();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                setState(() {
                  _dailyEntries[index]['text'] = textController.text.trim();
                });
                _saveDataSilently();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.month}/${date.day}/${date.year}';
  }

  String _getContinent() {
    final code = widget.countryCode;
    if ([
      'DZ',
      'AO',
      'BJ',
      'BW',
      'BF',
      'BI',
      'CM',
      'CV',
      'CF',
      'TD',
      'KM',
      'CG',
      'CD',
      'DJ',
      'EG',
      'GQ',
      'ER',
      'SZ',
      'ET',
      'GA',
      'GM',
      'GH',
      'GN',
      'GW',
      'CI',
      'KE',
      'LS',
      'LR',
      'LY',
      'MG',
      'MW',
      'ML',
      'MR',
      'MU',
      'MA',
      'MZ',
      'NA',
      'NE',
      'NG',
      'RW',
      'ST',
      'SN',
      'SC',
      'SL',
      'SO',
      'ZA',
      'SS',
      'SD',
      'TZ',
      'TG',
      'TN',
      'UG',
      'ZM',
      'ZW',
    ].contains(code)) {
      return 'Africa';
    } else if ([
      'AF',
      'AM',
      'AZ',
      'BH',
      'BD',
      'BT',
      'BN',
      'KH',
      'CN',
      'CY',
      'GE',
      'IN',
      'ID',
      'IR',
      'IQ',
      'IL',
      'JP',
      'JO',
      'KZ',
      'KW',
      'KG',
      'LA',
      'LB',
      'MY',
      'MV',
      'MN',
      'MM',
      'NP',
      'KP',
      'OM',
      'PK',
      'PS',
      'PH',
      'QA',
      'RU',
      'SA',
      'SG',
      'KR',
      'LK',
      'SY',
      'TW',
      'TJ',
      'TH',
      'TL',
      'TR',
      'TM',
      'AE',
      'UZ',
      'VN',
      'YE',
    ].contains(code)) {
      return 'Asia';
    } else if ([
      'AL',
      'AD',
      'AT',
      'BY',
      'BE',
      'BA',
      'BG',
      'HR',
      'CZ',
      'DK',
      'EE',
      'FI',
      'FR',
      'DE',
      'GR',
      'HU',
      'IS',
      'IE',
      'IT',
      'XK',
      'LV',
      'LI',
      'LT',
      'LU',
      'MT',
      'MD',
      'MC',
      'ME',
      'NL',
      'MK',
      'NO',
      'PL',
      'PT',
      'RO',
      'SM',
      'RS',
      'SK',
      'SI',
      'ES',
      'SE',
      'CH',
      'UA',
      'GB',
      'VA',
    ].contains(code)) {
      return 'Europe';
    } else if ([
      'AG',
      'BS',
      'BB',
      'BZ',
      'CA',
      'CR',
      'CU',
      'DM',
      'DO',
      'SV',
      'GD',
      'GT',
      'HT',
      'HN',
      'JM',
      'MX',
      'NI',
      'PA',
      'KN',
      'LC',
      'VC',
      'TT',
      'US',
    ].contains(code)) {
      return 'North America';
    } else if ([
      'AR',
      'BO',
      'BR',
      'CL',
      'CO',
      'EC',
      'GY',
      'PY',
      'PE',
      'SR',
      'UY',
      'VE',
    ].contains(code)) {
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
          child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
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
            // Header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: headerColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
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
                      child: Text(flag, style: const TextStyle(fontSize: 48)),
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

            // Quick Stats
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
                  // Daily Journal Section
                  _SectionHeader(
                    icon: Icons.book_rounded,
                    title: 'Daily Journal',
                    action: TextButton.icon(
                      onPressed: _addDailyEntry,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Entry'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5B7C99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_dailyEntries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 40,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No daily entries yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._dailyEntries.asMap().entries.map((entry) {
                      final index = entry.key;
                      final dailyEntry = entry.value;
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
                                  _formatDate(dailyEntry['date']!),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5B7C99),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _editDailyEntry(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dailyEntry['text']!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 32),

                  // Categories
                  _SectionHeader(
                    icon: Icons.category_rounded,
                    title: 'Categories',
                  ),
                  const SizedBox(height: 12),

                  _CategoryField(
                    icon: Icons.star_rounded,
                    label: 'Must Sees',
                    hint: 'Top attractions and landmarks...',
                    controller: _mustSeesController,
                  ),
                  const SizedBox(height: 12),

                  _CategoryField(
                    icon: Icons.explore_rounded,
                    label: 'Hidden Gems',
                    hint: 'Niche finds and local favorites...',
                    controller: _hiddenGemsController,
                  ),
                  const SizedBox(height: 12),

                  _CategoryField(
                    icon: Icons.restaurant_rounded,
                    label: 'Restaurants',
                    hint: 'Best places to eat...',
                    controller: _restaurantsController,
                  ),
                  const SizedBox(height: 12),

                  _CategoryField(
                    icon: Icons.local_bar_rounded,
                    label: 'Bars & Nightlife',
                    hint: 'Fun spots to go out...',
                    controller: _barsController,
                  ),

                  const SizedBox(height: 32),

                  // Photos
                  _SectionHeader(
                    icon: Icons.photo_library_rounded,
                    title: 'Photos',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_photosWithCaptions.length > 1)
                          TextButton.icon(
                            onPressed: _reorderPhotos,
                            icon: const Icon(Icons.swap_vert, size: 18),
                            label: const Text('Reorder'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5B7C99),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _addPhoto,
                          icon: const Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 18,
                          ),
                          label: const Text('Add Photo'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF5B7C99),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_photosWithCaptions.isEmpty)
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: _photosWithCaptions.length,
                      itemBuilder: (context, index) {
                        final photo = _photosWithCaptions[index];
                        return GestureDetector(
                          onTap: () => _viewPhoto(index),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                        child: Image.file(
                                          File(photo['path']!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  _editPhotoCaption(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => _removePhoto(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (photo['caption']!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      photo['caption']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2C3E50),
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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

class _CategoryField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;

  const _CategoryField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF5B7C99)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoReorderDialog extends StatefulWidget {
  final List<Map<String, String>> photos;
  final Function(List<Map<String, String>>) onReorder;

  const _PhotoReorderDialog({required this.photos, required this.onReorder});

  @override
  State<_PhotoReorderDialog> createState() => _PhotoReorderDialogState();
}

class _PhotoReorderDialogState extends State<_PhotoReorderDialog> {
  late List<Map<String, String>> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reorder Photos'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ReorderableListView.builder(
          itemCount: _photos.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = _photos.removeAt(oldIndex);
              _photos.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return Container(
              key: ValueKey(photo['path']),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photo['path']!),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      photo['caption']!.isEmpty
                          ? 'No caption'
                          : photo['caption']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: photo['caption']!.isEmpty
                            ? Colors.grey
                            : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        TextButton(
          onPressed: () {
            widget.onReorder(_photos);
            Navigator.pop(context);
          },
          child: const Text('Save Order'),
        ),
      ],
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
            Icon(icon, size: 24, color: const Color(0xFF5B7C99)),
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

  const _SectionHeader({required this.icon, required this.title, this.action});

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
