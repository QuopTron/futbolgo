import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stream_models.dart';
import '../services/backend_service.dart';
import '../services/update_service.dart';
import '../widgets/animated_entry.dart';
import '../widgets/channel_card.dart';
import '../widgets/event_card.dart';
import '../theme/theme_notifier.dart';
import '../widgets/glass_container.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/update_dialog.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StreamEvent> events = [];
  List<StreamChannel> channels = [];
  List<StreamChannel> previousChannels = [];
  bool isLoading = false;
  bool adBlockerEnabled = true;
  bool _backendAvailable = false;
  bool _backendChecked = false;
  DateTime? _lastUpdated;
  Timer? _autoRefreshTimer;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  bool _isInitialized = false;

  // Language filter
  String _languageFilter = 'Todas';
  static const _languages = ['Todas', 'ES', 'EN', 'PT', 'Otros'];

  // Status change tracking
  final Set<String> _justCameOnline = {};
  final Set<String> _justWentOffline = {};
  Timer? _clearStatusTimer;

  // App updates
  final UpdateService _updateService = UpdateService();
  AppVersion? _pendingUpdate;
  bool _updateChecking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _checkBackend();
    await _loadPreferences();
    await _loadStreams();
    _checkForAppUpdates();
    _startAutoRefresh();
    _isInitialized = true;
    if (mounted) setState(() {});
  }

  Future<void> _checkForAppUpdates() async {
    if (_updateChecking) return;
    
    _updateChecking = true;
    final update = await _updateService.checkForUpdates();
    _updateChecking = false;
    
    if (update != null && mounted) {
      setState(() {
        _pendingUpdate = update;
      });
      _showUpdateDialog(update);
    }
  }

  void _showUpdateDialog(AppVersion update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          update: update,
          onDismiss: () async {
            await _updateService.dismissUpdate(update.version);
            setState(() => _pendingUpdate = null);
            if (mounted) Navigator.pop(context);
          },
          onUpdate: () async {
            await _updateService.openUpdatePage(update.downloadUrl);
            setState(() => _pendingUpdate = null);
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    });
  }

  Future<void> _checkBackend() async {
    try {
      _backendAvailable = await BackendService().isAvailable();
    } catch (_) {
      _backendAvailable = false;
    }
    _backendChecked = true;
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        adBlockerEnabled = prefs.getBool('adBlockerEnabled') ?? true;
      });
    }
  }

  Future<void> _saveAdBlockerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adBlockerEnabled', adBlockerEnabled);
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadStreams(isAutoRefresh: true);
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        searchQuery = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _loadStreams({bool isAutoRefresh = false}) async {
    if (isLoading && !isAutoRefresh) return;

    if (!isAutoRefresh) {
      setState(() => isLoading = true);
    }

    try {
      for (final ch in channels) {
        ch.markBeforeUpdate();
      }
      previousChannels = List.from(channels);

      final data = await BackendService().scrapeAll();

      if (!mounted) return;
      setState(() {
        final newEvents = (data['events'] as List<dynamic>?)
                ?.map((e) => StreamEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final newChannels = (data['channels'] as List<dynamic>?)
                ?.map((e) => StreamChannel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        _justCameOnline.clear();
        _justWentOffline.clear();

        final prevMap = {for (final ch in previousChannels) ch.id: ch.isActive};
        for (final ch in newChannels) {
          final wasActive = prevMap[ch.id];
          if (wasActive != null && wasActive != ch.isActive) {
            if (ch.isActive) {
              _justCameOnline.add(ch.id);
            } else {
              _justWentOffline.add(ch.id);
            }
          }
        }

        _clearStatusTimer?.cancel();
        _clearStatusTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              _justCameOnline.clear();
              _justWentOffline.clear();
            });
          }
        });

        events = newEvents;
        channels = newChannels;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      if (events.isEmpty && channels.isEmpty) {
        setState(() {
          channels = [
            StreamChannel(id: 'ch_1', name: 'ESPN 1', isActive: true,
                isAdFree: true, streamUrl: 'https://streamtpday1.xyz/global1.php?stream=espn'),
            StreamChannel(id: 'ch_2', name: 'ESPN 2', isActive: true,
                isAdFree: true, streamUrl: 'https://streamtpday1.xyz/global1.php?stream=espn2'),
            StreamChannel(id: 'ch_3', name: 'ESPN Premium Argentina',
                isActive: true, isAdFree: true,
                streamUrl: 'https://streamtpday1.xyz/global1.php?stream=espnpremium'),
            StreamChannel(id: 'ch_4', name: 'TyC Sports', isActive: true,
                isAdFree: true, streamUrl: 'https://streamtpday1.xyz/global1.php?stream=tycsports'),
            StreamChannel(id: 'ch_5', name: 'TNT Sports Argentina',
                isActive: true, isAdFree: true,
                streamUrl: 'https://streamtpday1.xyz/global1.php?stream=tntsports'),
            StreamChannel(id: 'ch_6', name: 'Fox Sports 1 (Argentina)',
                isActive: true, isAdFree: true,
                streamUrl: 'https://streamtpday1.xyz/global1.php?stream=fox1ar'),
            StreamChannel(id: 'ch_7', name: 'Dsports', isActive: true,
                isAdFree: true, streamUrl: 'https://streamtpday1.xyz/global1.php?stream=dsports'),
            StreamChannel(id: 'ch_8', name: 'Sport TV 1 BR', isActive: true,
                isAdFree: true,
                streamUrl: 'https://streamtpday1.xyz/global1.php?stream=sporttvbr1'),
          ];
          _lastUpdated = DateTime.now();
        });
      }
    } finally {
      if (mounted && !isAutoRefresh) {
        setState(() => isLoading = false);
      }
    }
  }

  bool get _showShimmer =>
      (isLoading && events.isEmpty && channels.isEmpty) ||
      (_isInitialized && !_backendChecked);

  int get _activeChannelCount => StreamChannel.activeCount(channels);

  List<StreamChannel> get _filteredChannels {
    var result = channels;
    if (_languageFilter != 'Todas') {
      if (_languageFilter == 'Otros') {
        result = result
            .where((c) => !_languages.sublist(1, 4).contains(c.language))
            .toList();
      } else {
        result = result
            .where((c) => c.language == _languageFilter)
            .toList();
      }
    }
    if (searchQuery.isNotEmpty) {
      result = result
          .where((c) =>
              c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              c.language.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  List<StreamEvent> get _filteredEvents {
    var result = events;
    if (_languageFilter != 'Todas') {
      if (_languageFilter == 'Otros') {
        result = result
            .where((e) => !_languages.sublist(1, 4).contains(e.language))
            .toList();
      } else {
        result = result
            .where((e) => e.language == _languageFilter)
            .toList();
      }
    }
    if (searchQuery.isNotEmpty) {
      result = result
          .where((e) =>
              e.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              e.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
              e.language.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        blur: 20,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Buscar canales o eventos...',
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('FutbolGO',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      GlassContainer(
                        borderRadius: 8,
                        blur: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: EdgeInsets.zero,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        borderColor: Colors.white.withValues(alpha: 0.15),
                        child: Text(
                          '$_activeChannelCount EN VIVO',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ],
                  ),
                  if (_lastUpdated != null)
                    Text(
                      '${_formatTime(_lastUpdated!)} · ${channels.length} canales',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                ],
              ),
        actions: [
          // Update button
          GlassContainer(
            borderRadius: 20,
            blur: 6,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: EdgeInsets.zero,
            backgroundColor: _pendingUpdate != null
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderColor: _pendingUpdate != null
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            onTap: () => _checkForAppUpdates(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _updateChecking
                      ? Icons.hourglass_empty_rounded
                      : _pendingUpdate != null
                          ? Icons.new_releases_rounded
                          : Icons.system_update_alt_rounded,
                  size: 16,
                  color: _pendingUpdate != null
                      ? Colors.blue
                      : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Actualizar',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _pendingUpdate != null
                        ? Colors.blue
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Auto refresh toggle
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GlassContainer(
              borderRadius: 20,
              blur: 6,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: EdgeInsets.zero,
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              borderColor: Colors.white.withValues(alpha: 0.1),
              onTap: () {
                setState(() {
                  adBlockerEnabled = !adBlockerEnabled;
                });
                _saveAdBlockerPreference();
              },
              child: Icon(
                adBlockerEnabled
                    ? Icons.block_rounded
                    : Icons.block_flipped,
                size: 18,
                color: adBlockerEnabled ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
          // Ad blocker status badge
          GlassContainer(
            borderRadius: 20,
            blur: 6,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: EdgeInsets.zero,
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            borderColor: Colors.white.withValues(alpha: 0.1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4),
                Text(
                  'AdBlock',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color:
                        adBlockerEnabled ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, letterSpacing: 0.3),
          indicator: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 6),
                  Text('Eventos (${_filteredEvents.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.live_tv, size: 18),
                  const SizedBox(width: 6),
                  Text('Canales ($_activeChannelCount/${_filteredChannels.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0D1117),
              Color(0xFF080C1A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
          children: [
            // Backend status banner
            if (_backendChecked && !_backendAvailable)
              GlassContainer(
                borderRadius: 0,
                blur: 12,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.zero,
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                borderColor: Colors.orange.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Backend no disponible. Usando datos guardados.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orangeAccent),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadStreams(),
                      child: const Text('Reintentar',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),

            // Last updated indicator
            if (_lastUpdated != null && !_showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    GlassContainer(
                      borderRadius: 12,
                      blur: 6,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      margin: EdgeInsets.zero,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      borderColor: Colors.white.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Icon(Icons.update, size: 12,
                              color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Actualizado: ${_formatTime(_lastUpdated!)}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_justCameOnline.isNotEmpty ||
                        _justWentOffline.isNotEmpty)
                      GlassContainer(
                        borderRadius: 12,
                        blur: 6,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        margin: EdgeInsets.zero,
                        backgroundColor: _justCameOnline.isNotEmpty
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderColor: _justCameOnline.isNotEmpty
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_justCameOnline.isNotEmpty) ...[
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text('${_justCameOnline.length}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white70)),
                              const SizedBox(width: 4),
                            ],
                            if (_justWentOffline.isNotEmpty) ...[
                              Container(
                                width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: Colors.orange, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text('${_justWentOffline.length}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.orange)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // Language filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _languages.map((lang) {
                    final selected = _languageFilter == lang;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GlassContainer(
                        borderRadius: 14,
                        blur: 4,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        margin: EdgeInsets.zero,
                        backgroundColor: selected
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.03),
                        borderColor: selected
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.transparent,
                        onTap: () => setState(() => _languageFilter = lang),
                        child: Center(
                          child: Text(
                            lang,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? Colors.white : Colors.grey[400],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Main content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _showShimmer
                      ? const ShimmerLoading(type: ShimmerType.event, itemCount: 5)
                      : _buildEventsList(theme),
                  _showShimmer
                      ? const ShimmerLoading(type: ShimmerType.channel, itemCount: 6)
                      : _buildChannelsList(theme),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E1A), Color(0x000A0E1A)],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            const Text(
              'Powered by Flox',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white38,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            GlassContainer(
              borderRadius: 12,
              blur: 4,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: EdgeInsets.zero,
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              borderColor: Colors.white.withValues(alpha: 0.08),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update_alt_rounded, size: 12, color: Color(0xFF4FC3F7)),
                  const SizedBox(width: 4),
                  const Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4FC3F7),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassFAB(
            size: 48,
            icon: isLoading ? Icons.hourglass_top : Icons.refresh_rounded,
            tooltip: 'Actualizar',
            onPressed: () {
              setState(() {
                _lastUpdated = null;
                _justCameOnline.clear();
                _justWentOffline.clear();
              });
              _loadStreams();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(ThemeData theme) {
    final items = _filteredEvents;

    if (items.isEmpty) {
      return Center(
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          padding: const EdgeInsets.all(32),
          backgroundColor: Colors.white.withValues(alpha: 0.03),
          borderColor: Colors.white.withValues(alpha: 0.06),
          margin: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? 'Sin resultados para "$searchQuery"'
                    : 'No hay eventos deportivos en este momento',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GlassContainer(
                borderRadius: 12,
                blur: 6,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                borderColor: Colors.white.withValues(alpha: 0.12),
                onTap: () => _loadStreams(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.white70),
                    SizedBox(width: 6),
                    Text('Actualizar',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStreams(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: GlassContainer(
                borderRadius: 8,
                blur: 6,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.03),
                borderColor: Colors.white.withValues(alpha: 0.06),
                child: Text(
                  '${items.length} evento${items.length != 1 ? 's' : ''} disponible${items.length != 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500],
                      letterSpacing: 0.3),
                ),
              ),
            );
          }
          final event = items[index - 1];
          return AnimatedEntry(
            index: index - 1,
            child: EventCard(
              event: event,
              onTap: () => _playStream(event.playUrl, event.title, fallbackUrls: event.fallbackUrls),
              adBlockerEnabled: adBlockerEnabled,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelsList(ThemeData theme) {
    final items = _filteredChannels;

    if (items.isEmpty) {
      return Center(
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          padding: const EdgeInsets.all(32),
          backgroundColor: Colors.white.withValues(alpha: 0.03),
          borderColor: Colors.white.withValues(alpha: 0.06),
          margin: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📺', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? 'Sin resultados para "$searchQuery"'
                    : 'No hay canales disponibles',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GlassContainer(
                borderRadius: 12,
                blur: 6,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                borderColor: Colors.white.withValues(alpha: 0.12),
                onTap: () => _loadStreams(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.white70),
                    SizedBox(width: 6),
                    Text('Actualizar',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort: active first, then by language
    final sorted = List<StreamChannel>.from(items)
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final langCmp = a.language.compareTo(b.language);
        if (langCmp != 0) return langCmp;
        return a.name.compareTo(b.name);
      });

    return RefreshIndicator(
      onRefresh: () => _loadStreams(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemCount: sorted.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: GlassContainer(
                borderRadius: 8,
                blur: 6,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: EdgeInsets.zero,
                backgroundColor: Colors.white.withValues(alpha: 0.03),
                borderColor: Colors.white.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Text(
                      '${sorted.length} canales',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500],
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_activeChannelCount activos',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white70),
                    ),
                    const Spacer(),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: Colors.grey[600], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${sorted.length - _activeChannelCount} inactivos',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          }
          final channel = sorted[index - 1];
          return AnimatedEntry(
            index: index - 1,
            child: ChannelCard(
              channel: channel,
              onTap: () => _playStream(channel.playUrl, channel.name, fallbackUrls: channel.fallbackUrls),
              adBlockerEnabled: adBlockerEnabled,
              justCameOnline: _justCameOnline.contains(channel.id),
              justWentOffline: _justWentOffline.contains(channel.id),
            ),
          );
        },
      ),
    );
  }

  void _playStream(String url, String name, {List<String> fallbackUrls = const []}) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          streamUrl: url,
          adBlockerEnabled: adBlockerEnabled,
          channelName: name,
          fallbackUrls: fallbackUrls,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autoRefreshTimer?.cancel();
    _clearStatusTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
