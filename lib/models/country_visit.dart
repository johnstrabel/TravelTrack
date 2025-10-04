import 'privacy_settings.dart';

class PhotoWithCaption {
  final String path; // Local path
  final String caption;
  final String? url; // Cloud URL (null if not uploaded yet)
  final bool isPublic;

  PhotoWithCaption({
    required this.path,
    this.caption = '',
    this.url,
    this.isPublic = false,
  });

  factory PhotoWithCaption.fromJson(Map<String, dynamic> json) {
    return PhotoWithCaption(
      path: json['path'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      url: json['url'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'caption': caption,
      'url': url,
      'is_public': isPublic,
    };
  }
}

class DailyEntry {
  final String date; // ISO format
  final String text;

  DailyEntry({required this.date, required this.text});

  factory DailyEntry.fromJson(Map<String, dynamic> json) {
    return DailyEntry(
      date: json['date'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date, 'text': text};
  }
}

class CountryVisit {
  final String? id; // Supabase ID (null for local-only)
  final String userId;
  final String countryCode;
  final String? mustSees;
  final String? hiddenGems;
  final String? restaurants;
  final String? bars;
  final List<PhotoWithCaption> photos;
  final List<String> cities;
  final int rating;
  final DateTime? visitedDate;
  final List<DailyEntry> dailyEntries;
  final PrivacySettings privacy;
  final bool isPublic;

  CountryVisit({
    this.id,
    required this.userId,
    required this.countryCode,
    this.mustSees,
    this.hiddenGems,
    this.restaurants,
    this.bars,
    this.photos = const [],
    this.cities = const [],
    this.rating = 0,
    this.visitedDate,
    this.dailyEntries = const [],
    this.privacy = const PrivacySettings(),
    this.isPublic = false,
  });

  factory CountryVisit.fromJson(Map<String, dynamic> json) {
    return CountryVisit(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? 'local_user',
      countryCode: json['country_code'] as String,
      mustSees: json['must_sees'] as String?,
      hiddenGems: json['hidden_gems'] as String?,
      restaurants: json['restaurants'] as String?,
      bars: json['bars'] as String?,
      photos:
          (json['photos'] as List?)
              ?.map(
                (item) =>
                    PhotoWithCaption.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      cities: (json['cities'] as List?)?.cast<String>() ?? [],
      rating: json['rating'] as int? ?? 0,
      visitedDate: json['visited_date'] != null
          ? DateTime.parse(json['visited_date'] as String)
          : null,
      dailyEntries:
          (json['journal_entries'] as List?)
              ?.map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      privacy: PrivacySettings.fromJson(json),
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'country_code': countryCode,
      'must_sees': mustSees,
      'hidden_gems': hiddenGems,
      'restaurants': restaurants,
      'bars': bars,
      'photos': photos.map((p) => p.toJson()).toList(),
      'cities': cities,
      'rating': rating,
      'visited_date': visitedDate?.toIso8601String(),
      'journal_entries': dailyEntries.map((e) => e.toJson()).toList(),
      ...privacy.toJson(),
      'is_public': isPublic,
    };
  }

  // For local Hive storage (backward compatible)
  Map<String, dynamic> toHiveJson() {
    return {
      'mustSees': mustSees,
      'hiddenGems': hiddenGems,
      'restaurants': restaurants,
      'bars': bars,
      'photos': photos.map((p) => p.toJson()).toList(),
      'cities': cities,
      'rating': rating,
      'visitedDate': visitedDate?.toIso8601String(),
      'dailyEntries': dailyEntries.map((e) => e.toJson()).toList(),
    };
  }
}
