import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/countries.dart';
import '../models/country.dart';

class CountryListScreen extends StatefulWidget {
  final Function(String code) onToggle;
  final String? initialContinent; // <-- NEW

  const CountryListScreen({
    super.key,
    required this.onToggle,
    this.initialContinent, // <-- NEW
  });

  @override
  State<CountryListScreen> createState() => _CountryListScreenState();
}

class _CountryListScreenState extends State<CountryListScreen> {
  late final Box visitedBox;
  String _search = '';
  String _selectedContinent = 'All';

  @override
  void initState() {
    super.initState();
    visitedBox = Hive.box('visited_countries');
    if (!visitedBox.containsKey('codes')) {
      visitedBox.put('codes', <String>{});
    }

    // If a continent was provided, preselect it
    if (widget.initialContinent != null &&
        CountriesData.continents.contains(widget.initialContinent)) {
      _selectedContinent = widget.initialContinent!;
    }
  }

  Set<String> _visited() {
    final v = visitedBox.get('codes');
    if (v is Set) return v.cast<String>();
    if (v is List) return Set<String>.from(v);
    return <String>{};
  }

  List<Country> _filtered() {
    final s = _search.trim().toLowerCase();
    return CountriesData.allCountries.where((c) {
      final matchesCont = _selectedContinent == 'All' ||
          c.continent == _selectedContinent;
      final matchesSearch =
          s.isEmpty ||
          c.name.toLowerCase().contains(s) ||
          c.code.toLowerCase().contains(s);
      return matchesCont && matchesSearch;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _toggle(String code) {
    widget.onToggle(code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visited = _visited();
    final chips = ['All', ...CountriesData.continents];

    return Scaffold(
      appBar: AppBar(title: const Text('Select Countries')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Continent filter chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final label = chips[i];
                return ChoiceChip(
                  label: Text(label),
                  selected: _selectedContinent == label,
                  onSelected: (_) => setState(() => _selectedContinent = label),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Country list
          Expanded(
            child: ListView.builder(
              itemCount: _filtered().length,
              itemBuilder: (_, i) {
                final c = _filtered()[i];
                final isVisited = visited.contains(c.code);
                return CheckboxListTile(
                  title: Text(c.name),
                  subtitle: Text('${c.continent} • ${c.code}'),
                  value: isVisited,
                  onChanged: (_) => _toggle(c.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
