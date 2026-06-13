part of 'futbolgo_bloc.dart';

abstract class FutbolgoState extends Equatable {
  const FutbolgoState();
  @override
  List<Object?> get props => [];
}

class FutbolgoInitial extends FutbolgoState {
  const FutbolgoInitial();
}

class FutbolgoLoading extends FutbolgoState {
  const FutbolgoLoading();
}

class FutbolgoLoaded extends FutbolgoState {
  final List<StreamEvent> events;
  final List<StreamChannel> channels;
  final bool adBlockerEnabled;
  final String? languageFilter;
  final bool isRefreshing;

  const FutbolgoLoaded({
    required this.events,
    required this.channels,
    this.adBlockerEnabled = true,
    this.languageFilter,
    this.isRefreshing = false,
  });

  List<StreamEvent> get filteredEvents {
    if (languageFilter == null) return events;
    return events.where((e) => e.language == languageFilter).toList();
  }

  List<StreamChannel> get activeChannels =>
      channels.where((c) => c.isActive).toList();

  int get activeCount => StreamChannel.activeCount(channels);

  List<String> get availableLanguages {
    final langs = <String>{};
    for (final e in events) {
      if (e.language.isNotEmpty) langs.add(e.language);
    }
    final sorted = langs.toList()..sort();
    return sorted;
  }

  FutbolgoLoaded copyWith({
    List<StreamEvent>? events,
    List<StreamChannel>? channels,
    bool? adBlockerEnabled,
    String? languageFilter,
    bool? isRefreshing,
  }) {
    return FutbolgoLoaded(
      events: events ?? this.events,
      channels: channels ?? this.channels,
      adBlockerEnabled: adBlockerEnabled ?? this.adBlockerEnabled,
      languageFilter: languageFilter ?? this.languageFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [events, channels, adBlockerEnabled, languageFilter, isRefreshing];
}

class FutbolgoError extends FutbolgoState {
  final String message;
  const FutbolgoError(this.message);
  @override
  List<Object?> get props => [message];
}
