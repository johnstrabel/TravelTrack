class PrivacySettings {
  final bool photosPublic;
  final bool recommendationsPublic;
  final bool journalPublic;

  const PrivacySettings({
    this.photosPublic = false,
    this.recommendationsPublic = false,
    this.journalPublic = true, // Default: only journal is private
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      photosPublic: json['privacy_photos'] as bool? ?? false,
      recommendationsPublic: json['privacy_recommendations'] as bool? ?? false,
      journalPublic: json['privacy_journal'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privacy_photos': photosPublic,
      'privacy_recommendations': recommendationsPublic,
      'privacy_journal': journalPublic,
    };
  }
}
