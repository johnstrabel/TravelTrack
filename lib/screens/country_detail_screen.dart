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
  List<String> _photos = [];
  bool _isLoading = true;
  Timer? _autoSaveTimer;

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
    super.dispose();
  }

  void _onJournalChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveJournalSilently();
    });
  }

  Future<void> _loadData() async {
    _dataBox = await Hive.openBox('country_data');
    final countryData = _dataBox.get(widget.countryCode) as Map?;
    
    if (countryData != null) {
      _journalController.text = countryData['journal'] as String? ?? '';
      _photos = List<String>.from(countryData['photos'] as List? ?? []);
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveJournal() async {
    final currentData = _dataBox.get(widget.countryCode) as Map? ?? {};
    currentData['journal'] = _journalController.text;
    currentData['photos'] = _photos;
    
    await _dataBox.put(widget.countryCode, currentData);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Journal saved!'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveJournalSilently() async {
    final currentData = _dataBox.get(widget.countryCode) as Map? ?? {};
    currentData['journal'] = _journalController.text;
    currentData['photos'] = _photos;
    
    await _dataBox.put(widget.countryCode, currentData);
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
          await _saveJournalSilently();
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _photos.removeAt(index);
              });
              _saveJournalSilently();
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewPhoto(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.countryName),
          backgroundColor: const Color(0xFF4E79A7),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.countryName),
        backgroundColor: const Color(0xFF4E79A7),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveJournal,
            tooltip: 'Save Journal',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4E79A7).withOpacity(0.1),
                    const Color(0xFF4E79A7).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4E79A7).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    widget.countryName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E79A7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.countryCode,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Journal Section
            const Text(
              'Journal Entry',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _journalController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Write your memories, thoughts, and experiences...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4E79A7), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Auto-save',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Photos Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E79A7),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Photo Grid
            if (_photos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No photos yet',
                        style: TextStyle(color: Colors.grey[600]),
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
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _viewPhoto(_photos[index]),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photos[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              onPressed: () => _removePhoto(index),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}