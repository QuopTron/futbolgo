import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/stream_models.dart';
import '../services/backend_service.dart';

part 'futbolgo_event.dart';
part 'futbolgo_state.dart';

class FutbolgoBloc extends Bloc<FutbolgoEvent, FutbolgoState> {
  final BackendService _backend = BackendService();
  Timer? _pollTimer;

  FutbolgoBloc() : super(const FutbolgoInitial()) {
    on<LoadInitialData>(_onLoadInitial);
    on<RefreshData>(_onRefresh);
    on<ToggleAdBlocker>(_onToggleAdBlocker);
    on<FilterByLanguage>(_onFilterByLanguage);
    on<StartPolling>(_onStartPolling);
    on<StopPolling>(_onStopPolling);
  }

  Future<void> _onLoadInitial(LoadInitialData event, Emitter emit) async {
    emit(const FutbolgoLoading());
    try {
      final data = await _backend.scrapeAll();
      final events = (data['events'] as List)
          .map((e) => StreamEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      final channels = (data['channels'] as List)
          .map((c) => StreamChannel.fromJson(c as Map<String, dynamic>))
          .toList();
      emit(FutbolgoLoaded(
        events: events,
        channels: channels,
        adBlockerEnabled: event.adBlockerEnabled,
      ));
    } catch (e) {
      emit(FutbolgoError('Error al cargar: $e'));
    }
  }

  Future<void> _onRefresh(RefreshData event, Emitter emit) async {
    final current = state;
    if (current is FutbolgoLoaded) {
      emit(current.copyWith(isRefreshing: true));
    }
    try {
      final data = await _backend.scrapeAll();
      final events = (data['events'] as List)
          .map((e) => StreamEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      final channels = (data['channels'] as List)
          .map((c) {
            c.markBeforeUpdate();
            return StreamChannel.fromJson(c as Map<String, dynamic>);
          })
          .toList();
      emit(FutbolgoLoaded(
        events: events,
        channels: channels,
        adBlockerEnabled: (current is FutbolgoLoaded) ? current.adBlockerEnabled : true,
        languageFilter: (current is FutbolgoLoaded) ? current.languageFilter : null,
        isRefreshing: false,
      ));
    } catch (e) {
      if (current is FutbolgoLoaded) {
        emit(current.copyWith(isRefreshing: false));
      }
    }
  }

  void _onToggleAdBlocker(ToggleAdBlocker event, Emitter emit) {
    final current = state;
    if (current is FutbolgoLoaded) {
      emit(current.copyWith(adBlockerEnabled: !current.adBlockerEnabled));
    }
  }

  void _onFilterByLanguage(FilterByLanguage event, Emitter emit) {
    final current = state;
    if (current is FutbolgoLoaded) {
      emit(current.copyWith(
        languageFilter: event.language == current.languageFilter ? null : event.language,
      ));
    }
  }

  void _onStartPolling(StartPolling event, Emitter emit) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      add(const RefreshData());
    });
  }

  void _onStopPolling(StopPolling event, Emitter emit) {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
