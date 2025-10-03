import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/countries.dart';
import '../models/country.dart';
import 'country_detail_screen.dart';

class CountryListScreen extends StatefulWidget {
  final Function(String code) onToggle;
  final String? initialContinent;

  const CountryListScreen({
    super.key,
    required this.onToggle,
    this.initialContinent,
  });

  @override
  State<CountryListScreen> createState() => _CountryListScreenState();
}

class _CountryListScreenState extends State<CountryListScreen> {
  late final Box visitedBox;
  Box? dataBox;
  String _search = '';
  String _selectedContinent = 'All';
  bool _isLoading = true;

  static const Map<String, String> _flagEmojis = {
    // North America
    'US': '🇺🇸', 'CA': '🇨🇦', 'MX': '🇲🇽', 'AG': '🇦🇬', 'BS': '🇧🇸',
    'BB': '🇧🇧', 'BZ': '🇧🇿', 'CR': '🇨🇷', 'CU': '🇨🇺', 'DM': '🇩🇲',
    'DO': '🇩🇴', 'SV': '🇸🇻', 'GD': '🇬🇩', 'GT': '🇬🇹', 'HT': '🇭🇹',
    'HN': '🇭🇳', 'JM': '🇯🇲', 'NI': '🇳🇮', 'PA': '🇵🇦', 'KN': '🇰🇳',
    'LC': '🇱🇨', 'VC': '🇻🇨', 'TT': '🇹🇹',

    // South America
    'AR': '🇦🇷', 'BO': '🇧🇴', 'BR': '🇧🇷', 'CL': '🇨🇱', 'CO': '🇨🇴',
    'EC': '🇪🇨', 'GY': '🇬🇾', 'PY': '🇵🇾', 'PE': '🇵🇪', 'SR': '🇸🇷',
    'UY': '🇺🇾', 'VE': '🇻🇪',

    // Europe
    'AL': '🇦🇱', 'AD': '🇦🇩', 'AT': '🇦🇹', 'BY': '🇧🇾', 'BE': '🇧🇪',
    'BA': '🇧🇦', 'BG': '🇧🇬', 'HR': '🇭🇷', 'CZ': '🇨🇿', 'DK': '🇩🇰',
    'EE': '🇪🇪', 'FI': '🇫🇮', 'FR': '🇫🇷', 'DE': '🇩🇪', 'GR': '🇬🇷',
    'HU': '🇭🇺', 'IS': '🇮🇸', 'IE': '🇮🇪', 'IT': '🇮🇹', 'XK': '🇽🇰',
    'LV': '🇱🇻', 'LI': '🇱🇮', 'LT': '🇱🇹', 'LU': '🇱🇺', 'MT': '🇲🇹',
    'MD': '🇲🇩', 'MC': '🇲🇨', 'ME': '🇲🇪', 'NL': '🇳🇱', 'MK': '🇲🇰',
    'NO': '🇳🇴', 'PL': '🇵🇱', 'PT': '🇵🇹', 'RO': '🇷🇴', 'SM': '🇸🇲',
    'RS': '🇷🇸', 'SK': '🇸🇰', 'SI': '🇸🇮', 'ES': '🇪🇸', 'SE': '🇸🇪',
    'CH': '🇨🇭', 'UA': '🇺🇦', 'GB': '🇬🇧', 'VA': '🇻🇦',

    // Asia
    'AF': '🇦🇫', 'AM': '🇦🇲', 'AZ': '🇦🇿', 'BH': '🇧🇭', 'BD': '🇧🇩',
    'BT': '🇧🇹', 'BN': '🇧🇳', 'KH': '🇰🇭', 'CN': '🇨🇳', 'CY': '🇨🇾',
    'GE': '🇬🇪', 'IN': '🇮🇳', 'ID': '🇮🇩', 'IR': '🇮🇷', 'IQ': '🇮🇶',
    'IL': '🇮🇱', 'JP': '🇯🇵', 'JO': '🇯🇴', 'KZ': '🇰🇿', 'KW': '🇰🇼',
    'KG': '🇰🇬', 'LA': '🇱🇦', 'LB': '🇱🇧', 'MY': '🇲🇾', 'MV': '🇲🇻',
    'MN': '🇲🇳', 'MM': '🇲🇲', 'NP': '🇳🇵', 'KP': '🇰🇵', 'OM': '🇴🇲',
    'PK': '🇵🇰', 'PS': '🇵🇸', 'PH': '🇵🇭', 'QA': '🇶🇦', 'RU': '🇷🇺',
    'SA': '🇸🇦', 'SG': '🇸🇬', 'KR': '🇰🇷', 'LK': '🇱🇰', 'SY': '🇸🇾',
    'TW': '🇹🇼', 'TJ': '🇹🇯', 'TH': '🇹🇭', 'TL': '🇹🇱', 'TR': '🇹🇷',
    'TM': '🇹🇲', 'AE': '🇦🇪', 'UZ': '🇺🇿', 'VN': '🇻🇳', 'YE': '🇾🇪',

    // Africa
    'DZ': '🇩🇿', 'AO': '🇦🇴', 'BJ': '🇧🇯', 'BW': '🇧🇼', 'BF': '🇧🇫',
    'BI': '🇧🇮', 'CM': '🇨🇲', 'CV': '🇨🇻', 'CF': '🇨🇫', 'TD': '🇹🇩',
    'KM': '🇰🇲', 'CG': '🇨🇬', 'CD': '🇨🇩', 'DJ': '🇩🇯', 'EG': '🇪🇬',
    'GQ': '🇬🇶', 'ER': '🇪🇷', 'SZ': '🇸🇿', 'ET': '🇪🇹', 'GA': '🇬🇦',
    'GM': '🇬🇲', 'GH': '🇬🇭', 'GN': '🇬🇳', 'GW': '🇬🇼', 'CI': '🇨🇮',
    'KE': '🇰🇪', 'LS': '🇱🇸', 'LR': '🇱🇷', 'LY': '🇱🇾', 'MG': '🇲🇬',
    'MW': '🇲🇼', 'ML': '🇲🇱', 'MR': '🇲🇷', 'MU': '🇲🇺', 'MA': '🇲🇦',
    'MZ': '🇲🇿', 'NA': '🇳🇦', 'NE': '🇳🇪', 'NG': '🇳🇬', 'RW': '🇷🇼',
    'ST': '🇸🇹', 'SN': '🇸🇳', 'SC': '🇸🇨', 'SL': '🇸🇱', 'SO': '🇸🇴',
    'ZA': '🇿🇦', 'SS': '🇸🇸', 'SD': '🇸🇩', 'TZ': '🇹🇿', 'TG': '🇹🇬',
    'TN': '🇹🇳', 'UG': '🇺🇬', 'ZM': '🇿🇲', 'ZW': '🇿🇼',

    // Oceania
    'AU': '🇦🇺', 'FJ': '🇫🇯', 'KI': '🇰🇮', 'MH': '🇲🇭', 'FM': '🇫🇲',
    'NR': '🇳🇷', 'NZ': '🇳🇿', 'PW': '🇵🇼', 'PG': '🇵🇬', 'WS': '🇼🇸',
    'SB': '🇸🇧', 'TO': '🇹🇴', 'TV': '🇹🇻', 'VU': '🇻🇺',
  };

  @override
  void initState() {
    super.initState();
    visitedBox = Hive.box('visited_countries');
    if (!visitedBox.containsKey('codes')) {
      visitedBox.put('codes', <String>{});
    }

    if (widget.initialContinent != null &&
        CountriesData.continents.contains(widget.initialContinent)) {
      _selectedContinent = widget.initialContinent!;
    }

    _openDataBox();
  }

  Future<void> _openDataBox() async {
    dataBox = await Hive.openBox('country_data');
    setState(() {
      _isLoading = false;
    });
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
      final matchesCont =
          _selectedContinent == 'All' || c.continent == _selectedContinent;
      final matchesSearch =
          s.isEmpty ||
          c.name.toLowerCase().contains(s) ||
          c.code.toLowerCase().contains(s);
      return matchesCont && matchesSearch;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Country> _recentCountries() {
    if (dataBox == null) return [];

    final visited = _visited();
    final recentWithDates = <MapEntry<Country, DateTime>>[];

    for (final code in visited) {
      final country = CountriesData.findByCode(code);
      if (country == null) continue;

      final countryData = dataBox!.get(code) as Map?;
      final dateString = countryData?['visitedDate'] as String?;
      final date = dateString != null ? DateTime.tryParse(dateString) : null;

      if (date != null) {
        recentWithDates.add(MapEntry(country, date));
      }
    }

    recentWithDates.sort((a, b) => b.value.compareTo(a.value));
    return recentWithDates.take(5).map((e) => e.key).toList();
  }

  Country? _randomUnvisited() {
    final visited = _visited();
    final unvisited = CountriesData.allCountries
        .where((c) => !visited.contains(c.code))
        .toList();

    if (unvisited.isEmpty) return null;
    return unvisited[Random().nextInt(unvisited.length)];
  }

  String? _getVisitDate(String code) {
    if (dataBox == null) return null;

    final countryData = dataBox!.get(code) as Map?;
    final dateString = countryData?['visitedDate'] as String?;
    if (dateString == null) return null;

    final date = DateTime.tryParse(dateString);
    if (date == null) return null;

    return '${date.month}/${date.year}';
  }

  void _toggle(String code) {
    widget.onToggle(code);
    setState(() {});
  }

  void _openCountryDetail(Country country) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CountryDetailScreen(
          countryCode: country.code,
          countryName: country.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Countries'),
          backgroundColor: const Color(0xFF5B7C99),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
        ),
      );
    }

    final visited = _visited();
    final chips = ['All', ...CountriesData.continents];
    final recent = _recentCountries();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Countries'),
        backgroundColor: const Color(0xFF5B7C99),
      ),
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

          // Recent section
          if (recent.isNotEmpty &&
              _search.isEmpty &&
              _selectedContinent == 'All') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Color(0xFF5B7C99)),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Added',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            ...recent.map((c) {
              final flag = _flagEmojis[c.code] ?? '🏳️';
              final visitDate = _getVisitDate(c.code);
              return ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 32)),
                title: Text(c.name),
                subtitle: visitDate != null
                    ? Text(
                        'Added $visitDate',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    : null,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF5B7C99),
                ),
                onTap: () => _openCountryDetail(c),
              );
            }),
            const Divider(),
          ],

          // Country list
          Expanded(
            child: ListView.builder(
              itemCount: _filtered().length,
              itemBuilder: (_, i) {
                final c = _filtered()[i];
                final isVisited = visited.contains(c.code);
                final flag = _flagEmojis[c.code] ?? '🏳️';
                final visitDate = isVisited ? _getVisitDate(c.code) : null;

                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 32)),
                  title: Text(c.name),
                  subtitle: Row(
                    children: [
                      Text('${c.continent} • ${c.code}'),
                      if (visitDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• $visitDate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5B7C99),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Checkbox(
                    value: isVisited,
                    onChanged: (_) => _toggle(c.code),
                  ),
                  onTap: isVisited
                      ? () => _openCountryDetail(c)
                      : () => _toggle(c.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
