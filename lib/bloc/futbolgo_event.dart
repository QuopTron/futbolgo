part of 'futbolgo_bloc.dart';

abstract class FutbolgoEvent extends Equatable {
  const FutbolgoEvent();
  @override
  List<Object?> get props => [];
}

class LoadInitialData extends FutbolgoEvent {
  final bool adBlockerEnabled;
  const LoadInitialData({this.adBlockerEnabled = true});
  @override
  List<Object?> get props => [adBlockerEnabled];
}

class RefreshData extends FutbolgoEvent {
  const RefreshData();
}

class ToggleAdBlocker extends FutbolgoEvent {
  const ToggleAdBlocker();
}

class FilterByLanguage extends FutbolgoEvent {
  final String? language;
  const FilterByLanguage(this.language);
}

class StartPolling extends FutbolgoEvent {
  const StartPolling();
}

class StopPolling extends FutbolgoEvent {
  const StopPolling();
}
