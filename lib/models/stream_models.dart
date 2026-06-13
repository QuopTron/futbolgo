class StreamEvent {
  final String id;
  final String title;
  final String category;
  final String date;
  final String time;
  final String streamUrl;
  final String embedUrl;
  final String language;
  bool isLive;
  bool isActive;
  bool isAdFree;
  final String quality;
  final List<String> fallbackUrls;

  StreamEvent({
    required this.id,
    required this.title,
    this.category = '',
    this.date = '',
    this.time = '',
    this.streamUrl = '',
    this.embedUrl = '',
    this.language = 'ES',
    this.isLive = false,
    this.isActive = false,
    this.isAdFree = false,
    this.quality = 'HD',
    this.fallbackUrls = const [],
  });

  factory StreamEvent.fromJson(Map<String, dynamic> json) => StreamEvent(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Sin título',
        category: json['category'] ?? 'Deportes',
        date: json['date'] ?? '',
        time: json['time'] ?? '',
        streamUrl: json['stream_url'] ?? '',
        embedUrl: json['embed_url'] ?? '',
        language: json['language'] ?? 'ES',
        isLive: json['is_live'] ?? false,
        isActive: json['is_active'] ?? false,
        isAdFree: json['ad_free'] ?? false,
        quality: json['quality'] ?? 'HD',
        fallbackUrls: (json['fallback_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  String get playUrl => streamUrl.isNotEmpty ? streamUrl : embedUrl;
  bool get hasStream => streamUrl.isNotEmpty || embedUrl.isNotEmpty;
}

class StreamChannel {
  final String id;
  final String name;
  final String streamUrl;
  final String embedUrl;
  final String language;
  bool isActive;
  bool isAdFree;
  final String quality;
  final List<String> fallbackUrls;
  bool _wasActive = false;

  StreamChannel({
    required this.id,
    required this.name,
    this.streamUrl = '',
    this.embedUrl = '',
    this.language = 'ES',
    this.isActive = false,
    this.isAdFree = false,
    this.quality = 'HD',
    this.fallbackUrls = const [],
  });

  factory StreamChannel.fromJson(Map<String, dynamic> json) => StreamChannel(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Canal',
        streamUrl: json['stream_url'] ?? '',
        embedUrl: json['embed_url'] ?? '',
        language: json['language'] ?? 'ES',
        isActive: json['is_active'] ?? false,
        isAdFree: json['ad_free'] ?? false,
        quality: json['quality'] ?? 'HD',
        fallbackUrls: (json['fallback_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  String get playUrl => streamUrl.isNotEmpty ? streamUrl : embedUrl;
  bool get hasStream => streamUrl.isNotEmpty || embedUrl.isNotEmpty;

  /// Returns true if status JUST changed from inactive→active
  bool get justCameOnline => isActive && !_wasActive;

  /// Returns true if status JUST changed from active→inactive
  bool get justWentOffline => !isActive && _wasActive;

  /// Call before updating state to save previous status
  void markBeforeUpdate() => _wasActive = isActive;

  /// Get active channel count
  static int activeCount(List<StreamChannel> channels) =>
      channels.where((c) => c.isActive).length;
}

/// Category icons for events
class EventCategory {
  static const Map<String, String> icons = {
    'Fútbol': '⚽',
    'Liga MX': '⚽',
    'Premier League': '⚽',
    'La Liga': '⚽',
    'Serie A': '⚽',
    'Bundesliga': '⚽',
    'Ligue 1': '⚽',
    'UEFA': '⚽',
    'Champions': '⚽',
    'NBA': '🏀',
    'Baloncesto': '🏀',
    'Tenis': '🎾',
    'F1': '🏁',
    'Fórmula 1': '🏁',
    'Fórmula': '🏁',
    'Boxeo': '🥊',
    'MMA': '🥊',
    'UFC': '🥊',
    'NFL': '🏈',
    'Fútbol Americano': '🏈',
    'MLB': '⚾',
    'Béisbol': '⚾',
    'NHL': '🏒',
    'Hockey': '🏒',
    'Golf': '⛳',
    'Ciclismo': '🚴',
    'Atletismo': '🏃',
    'Vóley': '🏐',
    'Voleibol': '🏐',
    'Rugby': '🏉',
    'Motos': '🏍️',
    'MotoGP': '🏍️',
  };

  static String getIcon(String category) {
    for (final entry in icons.entries) {
      if (category.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return '🏆';
  }
}
