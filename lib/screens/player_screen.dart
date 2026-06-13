import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/glass_container.dart';
import '../services/backend_service.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final bool adBlockerEnabled;
  final String channelName;
  final List<String> fallbackUrls;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    this.adBlockerEnabled = true,
    this.channelName = '',
    this.fallbackUrls = const [],
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  // Media Kit (native video)
  Player? _mediaPlayer;
  VideoController? _videoController;

  // WebView (embedded web players)
  InAppWebViewController? _webViewController;

  bool _isMediaStream = false;
  bool _isWebView = false;
  bool _isLoading = true;
  double _progress = 0;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isPlaying = true;
  bool _isFullscreen = false;
  Timer? _controlsTimer;
  Timer? _loadingTimer;
  bool _orientationChecked = false;

  // Reconnection
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Timer? _bufferingTimer;
  bool _isReconnecting = false;

  // Live stream indicator (all streams are live)
  bool _isLiveStream = true;

  // Stream health monitoring
  DateTime? _lastSuccessfulPlay;
  Timer? _healthCheckTimer;
  Timer? _audioSilenceTimer;
  bool _hasPlayedSuccessfully = false;

  // Quality selector
  String _currentQuality = 'Auto';
  late String _originalStreamUrl;
  String _currentStreamUrl = '';
  List<_QualityOption> _availableQualities = [];
  bool _isChangingQuality = false;

  // Stream resolution (avoids WebView for PHP streams)
  bool _streamResolved = false;
  String _resolvedM3u8Url = '';

  // Fallback
  List<String> _remainingFallbacks = [];
  int _fallbackIndex = 0;

  // Debug overlay
  bool _showDebugOverlay = false;
  DateTime? _loadStartTime;
  final List<_DebugLogEntry> _debugLogs = [];
  final ScrollController _debugScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _originalStreamUrl = widget.streamUrl;
    _currentStreamUrl = widget.streamUrl;
    _remainingFallbacks = List.from(widget.fallbackUrls);
    _logDebug('App iniciada');
    _logDebug('URL original: ${_truncateUrl(widget.streamUrl)}');
    _initAvailableQualities();
    _tryResolveStream();
  }

  Future<void> _tryResolveStream() async {
    _loadStartTime = DateTime.now();
    final url = _currentStreamUrl;

    // If it's already an m3u8 or direct media URL, skip resolution
    if (_isDirectStreamUrl(url)) {
      _logDebug('URL directa, saltando resolución');
      _streamResolved = true;
      _resolvedM3u8Url = url;
      _detectStreamType();
      return;
    }

    // If the URL is from sudamericaplay2, skip resolution and WebView entirely
    // These pages have anti-framekill scripts that crash the WebView renderer
    if (_isUnresolvableUrl(url)) {
      _logDebug('⚠️ URL no soportada para resolución, intentando fallbacks...');
      _streamResolved = false;
      _tryFallbackStream();
      return;
    }

    _logDebug('🔍 Resolviendo stream vía backend...');
    try {
      final result = await BackendService().resolveStream(url);
      final resolved = result['resolved'] == true;
      if (resolved && result['m3u8_url'] != null) {
        final m3u8 = result['m3u8_url'] as String;
        _logDebug('✅ Stream resuelto a: ${_truncateUrl(m3u8)}');
        _streamResolved = true;
        _resolvedM3u8Url = m3u8;
        _originalStreamUrl = m3u8;
        _currentStreamUrl = m3u8;
        _detectStreamType();
        return;
      }
      _logDebug('⚠️ No se pudo resolver: ${result['error'] ?? 'desconocido'}');
    } catch (e) {
      _logDebug('⚠️ Error resolución: $e');
    }

    // Fallback: try fallback channels instead of showing WebView with ads
    _streamResolved = false;
    _tryFallbackStream();
  }

  /// Returns true for URLs that are known to be impossible to resolve or
  /// that have anti-framekill scripts (sudamericaplay2.com, etc.)
  bool _isUnresolvableUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('sudamericaplay') ||
        lower.contains('histats.com') ||
        lower.contains('/block.html') ||
        lower.endsWith('.html') && !lower.contains('global1.php');
  }

  bool _isDirectStreamUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.m3u8') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.contains('index.m3u8');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_orientationChecked) {
      _orientationChecked = true;
      _checkInitialOrientation();
    }
  }

  @override
  void didUpdateWidget(PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disposePlayer();
      _reconnectAttempts = 0;
      _fallbackIndex = 0;
      _remainingFallbacks = List.from(widget.fallbackUrls);
      _streamResolved = false;
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _isReconnecting = false;
        _currentStreamUrl = widget.streamUrl;
        _originalStreamUrl = widget.streamUrl;
      });
      _tryResolveStream();
    }
  }

  void _checkInitialOrientation() {
    final size = MediaQuery.of(context).size;
    if (size.width > size.height) {
      _enterFullscreen();
    }
  }

  @override
  void didChangeMetrics() {}

  void _enterFullscreen() {
    if (_isFullscreen) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: []);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) setState(() => _isFullscreen = true);
  }

  void _exitFullscreen() {
    if (!_isFullscreen) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) setState(() => _isFullscreen = false);
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isLoading) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_showControls) setState(() => _showControls = true);
    _startControlsTimer();
  }

  void _detectStreamType() {
    final playUrl = _streamResolved && _resolvedM3u8Url.isNotEmpty
        ? _resolvedM3u8Url
        : widget.streamUrl;
    _currentStreamUrl = playUrl;
    final url = playUrl.toLowerCase();

    final isDirectMedia = url.endsWith('.m3u8') ||
        url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mkv') ||
        url.contains('.m3u8') ||
        url.contains('manifest') ||
        url.contains('playlist') ||
        url.contains('/hls/') ||
        url.contains('/dash/') ||
        url.contains('.ts') ||
        (url.contains('media') && url.contains('.php')) ||
        // PHP-based stream proxies often deliver HLS
        url.contains('global1.php?') ||
        url.contains('stream.php?') ||
        url.contains('play.php?') ||
        url.contains('player.php?') ||
        url.contains('getstream') ||
        url.contains('.php?stream=');

    setState(() {
      _isMediaStream = isDirectMedia;
      _isWebView = !isDirectMedia;
    });

    _logDebug('Tipo detectado: ${isDirectMedia ? "media_kit" : "WebView"}');
    _loadStartTime = DateTime.now();

    if (_isMediaStream) {
      _initMediaPlayer();
    }
  }

  /// Initialize available quality options based on the stream URL patterns
  void _initAvailableQualities() {
    _availableQualities = [
      _QualityOption(label: 'Auto', description: 'Automático', icon: Icons.smart_toy_rounded, buildUrl: _originalStreamUrl),
      _QualityOption(label: 'HD', description: '1080p · Alta calidad', icon: Icons.high_quality_rounded, buildUrl: _buildQualityUrl('HD')),
      _QualityOption(label: 'SD', description: '480p · Ahorro de datos', icon: Icons.sd_rounded, buildUrl: _buildQualityUrl('SD')),
      _QualityOption(label: 'Baja', description: '240p · Máximo ahorro', icon: Icons.movie_creation_rounded, buildUrl: _buildQualityUrl('Baja')),
    ];
  }

  /// Build a stream URL for a specific quality by trying common patterns
  String _buildQualityUrl(String quality) {
    final url = _originalStreamUrl;
    if (quality == 'Auto' || url.isEmpty) return url;

    // Common quality parameters
    final qParam = quality.toLowerCase();
    final qMap = {'HD': 'hd', 'SD': 'sd', 'Baja': 'low'};
    final q = qMap[quality] ?? qParam;

    try {
      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      // Pattern 1: ?stream=NAME → try adding ?stream=NAME&q=hd
      if (queryParams.containsKey('stream')) {
        return uri.replace(queryParameters: {
          ...queryParams,
          'q': q,
        }).toString();
      }

      // Pattern 2: If it's an m3u8 URL, try replacing suffix
      if (url.contains('.m3u8')) {
        final base = url.replaceAll(RegExp(r'(?:_(?:hd|sd|low))?\.m3u8$'), '');
        return '$base${q != 'hd' ? '_$q' : ''}.m3u8';
      }

      // Pattern 3: If URL already has query params, add quality
      if (queryParams.isNotEmpty) {
        return uri.replace(queryParameters: {
          ...queryParams,
          'quality': q,
        }).toString();
      }

      // Pattern 4: Add ?quality=hd as last resort
      if (url.contains('?')) {
        return '$url&quality=$q';
      }
      return '$url?quality=$q';
    } catch (_) {
      return url;
    }
  }

  /// Show quality selector bottom sheet
  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => _QualitySheet(
        currentQuality: _currentQuality,
        availableQualities: _availableQualities,
        onSelect: (quality) {
          Navigator.pop(ctx);
          if (quality != _currentQuality) {
            _changeQuality(quality);
          }
        },
      ),
    );
  }

  /// Change quality and restart the player
  void _changeQuality(String newQuality) {
    if (_isChangingQuality) return;
    _isChangingQuality = true;
    final newUrl = _availableQualities.firstWhere(
      (q) => q.label == newQuality,
      orElse: () => _availableQualities.first,
    ).buildUrl;

    _logDebug('🎯 Calidad cambiada a $newQuality: ${_truncateUrl(newUrl)}');

    setState(() {
      _currentQuality = newQuality;
      _isLoading = true;
      _errorMessage = '';
      _isReconnecting = false;
    });

    _loadStartTime = DateTime.now();

    // Dispose current player and re-init with new URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentStreamUrl = newUrl;
      _disposePlayer();
      if (_isMediaStream) {
        _initMediaPlayer();
      } else {
        _logDebug('🌐 WebView: cargando nueva URL...');
        _webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(newUrl)),
        );
        _isChangingQuality = false;
      }
    });
  }

  Future<void> _initMediaPlayer() async {
    _logDebug('🎬 Inicializando media_kit...');
    try {
      final player = Player();
      _mediaPlayer = player;
      _videoController = VideoController(player);

      player.stream.error.listen((error) {
        if (!mounted) return;
        _logDebug('❌ Error media_kit: $error');
        final errorStr = error.toString().toLowerCase();
        
        if (errorStr.contains('url') || errorStr.contains('404') || errorStr.contains('not found') || 
            errorStr.contains('network') || errorStr.contains('connection')) {
          _logDebug('🔄 Error de URL/redetectado, reintentando...');
          setState(() {
            _errorMessage = 'El stream se ha actualizado, reconectando...';
            _isLoading = true;
          });
          _reconnectAttempts = 0;
          _tryAutoReconnect();
        } else {
          setState(() {
            _errorMessage = 'Error al reproducir: $error';
            _isLoading = false;
          });
          _tryAutoReconnect();
        }
      });

      player.stream.completed.listen((_) {
        if (!mounted) return;
        _logDebug('⏹️ Stream finalizado (completed)');
        if (_hasPlayedSuccessfully && _isPlaying) {
          _logDebug('🔄 Stream finalizó inesperadamente, reconectando...');
          _reconnectAttempts = 0;
          _tryAutoReconnect();
        }
      });

      player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        _bufferingTimer?.cancel();
        if (buffering) {
          _logDebug('⏳ Buffering...');
        } else {
          _logDebug('✅ Buffering terminado');
          _lastSuccessfulPlay = DateTime.now();
        }
        if (buffering && _mediaPlayer != null) {
          _bufferingTimer = Timer(const Duration(seconds: 10), () {
            if (mounted && _isLoading && !_isReconnecting) {
              _logDebug('⚠️ Stuck en buffering >10s');
              _tryAutoReconnect();
            }
          });
        }
      });

      player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
          if (playing) {
            _logDebug('▶️ Reproduciendo (${_formatElapsed(_loadStartTime)})');
            setState(() => _isLoading = false);
            _hasPlayedSuccessfully = true;
            _lastSuccessfulPlay = DateTime.now();
            _showControlsTemporarily();
            
            _audioSilenceTimer?.cancel();
            _healthCheckTimer?.cancel();
            _startHealthMonitoring();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensureVolume();
            });
          } else {
            _healthCheckTimer?.cancel();
            _audioSilenceTimer?.cancel();
          }
        }
      });

      player.stream.position.listen((position) {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
        if (mounted && _isPlaying) {
          _lastSuccessfulPlay = DateTime.now();
        }
      });

      await player.open(Media(_currentStreamUrl));

      _isChangingQuality = false;

      _lastSuccessfulPlay = DateTime.now();
      _hasPlayedSuccessfully = false;
      _startHealthMonitoring();

      _loadingTimer?.cancel();
      _loadingTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && _isLoading) {
          _logDebug('⚠️ Timeout de carga (20s)');
          setState(() {
            _errorMessage = 'El stream está tardando en cargar.';
            _isLoading = false;
          });
          _tryAutoReconnect();
        }
      });
    } catch (e) {
      if (!mounted) return;
      _logDebug('❌ Error init media_kit: $e');
      setState(() {
        _errorMessage = 'No se pudo iniciar el reproductor: $e';
        _isLoading = false;
      });
      _isChangingQuality = false;
      _tryAutoReconnect();
    }
  }

  void _tryAutoReconnect() {
    if (_isReconnecting) return;

    _reconnectAttempts++;
    _isReconnecting = true;
    final mode = _isMediaStream ? 'media_kit' : 'WebView';
    _logDebug('🔄 Reconexión intento $_reconnectAttempts/$_maxReconnectAttempts ($mode)');

    setState(() {
      _isLoading = true;
      _errorMessage = 'Reconectando (intento $_reconnectAttempts)...';
    });

    _loadStartTime = DateTime.now();

    _reconnectTimer?.cancel();
    
    final delay = _reconnectAttempts < 2 
        ? Duration(seconds: 2) 
        : Duration(seconds: _reconnectAttempts * 2);
    
    _reconnectTimer = Timer(delay, () {
      if (!mounted) return;
      _isReconnecting = false;
      if (_isMediaStream) {
        _mediaPlayer?.dispose();
        _mediaPlayer = null;
        _videoController = null;
        _initMediaPlayer();
      } else {
        _logDebug('🌐 Recargando WebView...');
        _webViewController?.reload();
        _loadingTimer?.cancel();
        _loadingTimer = Timer(const Duration(seconds: 20), () {
          if (mounted && _isLoading) {
            setState(() => _isLoading = false);
          }
        });
      }
    });

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logDebug('⚠️máximo de reconexiones alcanzado, intentando fallback...');
      Timer(const Duration(milliseconds: 500), () => _tryFallbackStream());
    }
  }

  void _tryFallbackStream() {
    if (_remainingFallbacks.isEmpty) {
      _logDebug('❌ No hay más fallbacks disponibles');
      setState(() => _errorMessage = 'No hay streams disponibles');
      return;
    }

    final fallbackUrl = _remainingFallbacks.removeAt(0);
    _fallbackIndex++;
    _logDebug('🔄 Intentando fallback $_fallbackIndex: ${_truncateUrl(fallbackUrl)}');

    _reconnectAttempts = 0;
    _isReconnecting = false;
    _streamResolved = false;

    setState(() {
      _isLoading = true;
      _errorMessage = 'Probando stream alternativo...';
      _currentStreamUrl = fallbackUrl;
      _originalStreamUrl = fallbackUrl;
    });

    _disposePlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryResolveStream();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _loadingTimer?.cancel();
    _reconnectTimer?.cancel();
    _bufferingTimer?.cancel();
    _healthCheckTimer?.cancel();
    _audioSilenceTimer?.cancel();
    _debugScrollController.dispose();
    _disposePlayer();
    _exitFullscreen();
    super.dispose();
  }

  void _disposePlayer() {
    _healthCheckTimer?.cancel();
    _audioSilenceTimer?.cancel();
    _mediaPlayer?.dispose();
    _mediaPlayer = null;
    _videoController = null;
    _webViewController = null;
  }

  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _audioSilenceTimer?.cancel();

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_isPlaying || _isReconnecting) return;

      final now = DateTime.now();
      final timeSinceLastPlay = _lastSuccessfulPlay != null
          ? now.difference(_lastSuccessfulPlay!).inSeconds
          : 0;

      if (_hasPlayedSuccessfully && timeSinceLastPlay > 20) {
        _logDebug('⚠️ Stream stale: No updates >20s, reconectando...');
        setState(() {
          _errorMessage = 'Reconectando stream...';
          _isLoading = true;
        });
        _tryAutoReconnect();
      }
    });

    _audioSilenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_isPlaying || _isReconnecting) return;
      
      _ensureVolume();
      _checkStreamHealth();
    });
  }

  Future<void> _ensureVolume() async {
    if (_mediaPlayer == null) return;
    
    try {
      final volumeSubscription = _mediaPlayer!.stream.volume.listen((volume) {
        if (volume == 0 && mounted) {
          _logDebug('🔊 Audio silenciado por stream, reactivando...');
          _mediaPlayer!.setVolume(1.0);
        }
      });
      
      volumeSubscription.cancel();
    } catch (e) {
      _logDebug('Error checking volume: $e');
    }
  }

  Future<void> _checkStreamHealth() async {
    if (_mediaPlayer == null || _isReconnecting) return;
    
    try {
      Duration? duration;
      Duration? position;
      bool? playing;

      final durationSub = _mediaPlayer!.stream.duration.listen((d) {
        duration = d;
      });
      final positionSub = _mediaPlayer!.stream.position.listen((p) {
        position = p;
      });
      final playingSub = _mediaPlayer!.stream.playing.listen((p) {
        playing = p;
      });

      await Future.delayed(const Duration(milliseconds: 100));

      durationSub.cancel();
      positionSub.cancel();
      playingSub.cancel();

      if (playing == true && position != null && duration != null) {
        if (position! > Duration.zero && duration! > Duration.zero) {
          if (position!.inSeconds >= duration!.inSeconds - 5 && _isLiveStream) {
            _logDebug('⚠️ Stream parece estar en loop, reconectando...');
            _reconnectAttempts = 0;
            _tryAutoReconnect();
          }
        }
      }
    } catch (e) {
      _logDebug('Stream health check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isFullscreen ? null : _buildGlassAppBar(theme),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1117), Colors.black],
          ),
        ),
        child: _isMediaStream
            ? _buildMediaPlayer(theme)
            : _buildWebViewPlayer(theme),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(ThemeData theme) {
    return GlassAppBar(
      blur: 20,
      title: Text(
        widget.channelName.isNotEmpty ? widget.channelName : 'Reproductor',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Tappable quality badge — opens quality selector
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            borderRadius: 20,
            blur: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            borderColor: Colors.white.withValues(alpha: 0.12),
            onTap: _showQualitySelector,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentQuality == 'Auto'
                      ? Icons.smart_toy_rounded
                      : Icons.high_quality_rounded,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(_currentQuality,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 14, color: Colors.white38),
              ],
            ),
          ),
        ),
        // WEB badge (when in WebView mode, still show)
        if (!_isMediaStream)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              borderRadius: 20,
              blur: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              borderColor: Colors.white.withValues(alpha: 0.12),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.web, size: 14, color: Colors.white54),
                  SizedBox(width: 4),
                  Text('WEB',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54)),
                ],
              ),
            ),
          ),
        // Debug toggle
        IconButton(
          icon: Icon(
            _showDebugOverlay ? Icons.bug_report_rounded : Icons.bug_report_outlined,
            color: _showDebugOverlay ? Colors.amber : null,
          ),
          tooltip: 'Debug: ${_showDebugOverlay ? "ocultar" : "mostrar"}',
          onPressed: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recargar',
          onPressed: _reload,
        ),
        IconButton(
          icon: const Icon(Icons.open_in_browser),
          tooltip: 'Abrir en navegador',
          onPressed: () async {
            final uri = Uri.tryParse(widget.streamUrl);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Native video player using media_kit with gesture overlay
  Widget _buildMediaPlayer(ThemeData theme) {
    if (_isLoading && _mediaPlayer == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Video player wrapped with gesture listener
        Listener(
          onPointerUp: (event) {
            if (_showControls) {
              setState(() => _showControls = false);
              _controlsTimer?.cancel();
            } else {
              _showControlsTemporarily();
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _videoController != null
                ? Video(
                    controller: _videoController!,
                    fill: Colors.black,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),

        // Loading overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white38),
                    SizedBox(height: 16),
                    Text('Conectando con el stream...',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                    SizedBox(height: 8),
                    Text('Esto puede tomar unos segundos',
                        style: TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

        // Controls overlay
        if (_showControls && !_isLoading)
          _buildControlsOverlay(theme),

        // Error banner
        if (_errorMessage.isNotEmpty)
          Positioned(
            top: _isFullscreen ? 20 : 60,
            left: 16,
            right: 16,
            child: GlassContainer(
              borderRadius: 12,
              blur: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
              borderColor: Colors.orange.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orangeAccent),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Reintentar',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),

        // Fallback: toggle between media_kit and WebView
        if (_errorMessage.isNotEmpty && !_isReconnecting && !_isLoading)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reconnect button (if within max attempts)
                  if (_reconnectAttempts > 0 && _reconnectAttempts < _maxReconnectAttempts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassContainer(
                        borderRadius: 24,
                        blur: 12,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        borderColor: Colors.white.withValues(alpha: 0.15),
                        onTap: () {
                          _reconnectAttempts = 0;
                          _reload();
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 18, color: Colors.white60),
                            SizedBox(width: 8),
                            Text('Reintentar',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  // Toggle player type
                  GlassContainer(
                    borderRadius: 24,
                    blur: 12,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    borderColor: Colors.white.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() {
                        _isMediaStream = !_isMediaStream;
                        _isWebView = !_isMediaStream;
                        _errorMessage = '';
                        _isLoading = true;
                        _reconnectAttempts = 0;
                        _isReconnecting = false;
                      });
                      // Re-init with the new type
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _disposePlayer();
                        if (_isMediaStream) {
                          _initMediaPlayer();
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMediaStream
                              ? Icons.language
                              : Icons.videocam_rounded,
                          size: 18,
                          color: Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isMediaStream
                              ? 'Abrir con WebView'
                              : 'Usar reproductor nativo',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Reconnection overlay
        if (_isReconnecting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white38),
                    const SizedBox(height: 16),
                    Text(
                      'Reconectando (intento $_reconnectAttempts/$_maxReconnectAttempts)...',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Debug overlay (on top of everything)
        if (_showDebugOverlay) _buildDebugOverlay(),
      ],
    );
  }

  /// Build debug overlay showing live logs
  Widget _buildDebugOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          color: const Color(0xCC0A0E1A),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xAA1C2128),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    const Text('DEBUG',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    _debugChip('${_isMediaStream ? "📦 media_kit" : "🌐 WebView"}', Colors.cyanAccent),
                    const SizedBox(width: 4),
                    _debugChip(_currentQuality, Colors.amber),
                    const SizedBox(width: 4),
                    _debugChip(_isPlaying ? '▶️' : '⏸️', Colors.greenAccent),
                    const SizedBox(width: 4),
                    _debugChip('${_debugLogs.length}', Colors.white54),
                  ],
                ),
              ),
              // Logs
              Expanded(
                child: ListView.builder(
                  controller: _debugScrollController,
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  itemCount: _debugLogs.length,
                  itemBuilder: (context, index) {
                    final entry = _debugLogs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      child: Text(
                        entry.formatted,
                        style: TextStyle(
                          color: entry.color,
                          fontSize: 9,
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _truncateUrl(String url) {
    if (url.length <= 60) return url;
    return '${url.substring(0, 30)}...${url.substring(url.length - 25)}';
  }

  String _formatElapsed(DateTime? start) {
    if (start == null) return '-';
    final elapsed = DateTime.now().difference(start);
    if (elapsed.inSeconds < 60) return '${elapsed.inSeconds}s';
    return '${elapsed.inMinutes}m ${elapsed.inSeconds.remainder(60)}s';
  }

  void _logDebug(String message) {
    _debugLogs.add(_DebugLogEntry(message));
    // Keep last 100 entries
    if (_debugLogs.length > 100) {
      _debugLogs.removeAt(0);
    }
    // Auto-scroll if near bottom
    if (_debugScrollController.hasClients) {
      final maxScroll = _debugScrollController.position.maxScrollExtent;
      final currentScroll = _debugScrollController.position.pixels;
      if (maxScroll - currentScroll < 50) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_debugScrollController.hasClients) {
            _debugScrollController.animateTo(
              _debugScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  /// Controls overlay with top bar + bottom controls
  Widget _buildControlsOverlay(ThemeData theme) {
    return Column(
      children: [
        // Top bar (fullscreen)
        if (_isFullscreen)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 200),
            child: GlassContainer(
              borderRadius: 0,
              blur: 20,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 8,
                left: 8,
                right: 8,
              ),
              margin: EdgeInsets.zero,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              borderColor: Colors.transparent,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.channelName.isNotEmpty
                          ? widget.channelName
                          : 'Reproductor',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_exit_rounded,
                        color: Colors.white54),
                    tooltip: 'Salir de pantalla completa',
                    onPressed: _exitFullscreen,
                  ),
                ],
              ),
            ),
          ),

        const Spacer(),

        // Bottom controls
        _buildVideoControls(theme),
      ],
    );
  }

  /// Video controls — B&W glass style
  Widget _buildVideoControls(ThemeData theme) {
    return GlassContainer(
      borderRadius: 0,
      blur: 20,
      padding: EdgeInsets.fromLTRB(
          8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress slider
          if (_mediaPlayer != null)
   // Show live indicator instead of progress slider for live streams
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 8),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                   decoration: BoxDecoration(
                     color: Colors.red.withValues(alpha: 0.2),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                   ),
                   child: const Text(
                     'EN VIVO',
                     style: TextStyle(
                       color: Colors.red,
                       fontSize: 11,
                       fontWeight: FontWeight.w700,
                       letterSpacing: 1.0,
                     ),
                   ),
                 ),
               ],
             ),
           ),
          const SizedBox(height: 4),
          // Controls row
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_isPlaying) {
                    _mediaPlayer?.pause();
                  } else {
                    _mediaPlayer?.play();
                  }
                  if (!_showControls) _showControlsTemporarily();
                },
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded,
                    color: Colors.white54, size: 20),
                onPressed: () {
                  _mediaPlayer?.seek(Duration.zero);
                  _mediaPlayer?.play();
                },
              ),
              const Spacer(),
              if (_mediaPlayer != null)
                StreamBuilder<double>(
                  stream: _mediaPlayer!.stream.volume,
                  builder: (context, snapshot) {
                    final volume = snapshot.data ?? 1.0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            volume > 0.5
                                ? Icons.volume_up_rounded
                                : volume > 0
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_off_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                            _mediaPlayer?.setVolume(volume > 0 ? 0 : 1.0);
                          },
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 600
                              ? 100
                              : 60,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12),
                              activeTrackColor: Colors.white54,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              overlayColor:
                                  Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Slider(
                              value: volume,
                              onChanged: (v) {
                                _mediaPlayer?.setVolume(v);
                                _showControlsTemporarily();
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(width: 4),
              // Quality selector button
              IconButton(
                icon: Icon(
                  _currentQuality == 'Auto'
                      ? Icons.smart_toy_rounded
                      : Icons.high_quality_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                tooltip: 'Calidad: $_currentQuality',
                onPressed: _isChangingQuality ? null : _showQualitySelector,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                tooltip: _isFullscreen
                    ? 'Salir de pantalla completa'
                    : 'Pantalla completa',
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// WebView player for embedded streams
  Widget _buildWebViewPlayer(ThemeData theme) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.streamUrl)),
          initialUserScripts: UnmodifiableListView<UserScript>([
            // Inject anti-anti-framekill + ad-block BEFORE any page JS runs
            UserScript(
              source: _adBlockUserScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
          ]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            clearCache: false,
            // useHybridComposition NO se usa — causa EGL_BAD_ATTRIBUTE en emuladores Android con GPU software
            transparentBackground: true,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            _logDebug('🌐 WebView creado');
            _webViewController = controller;
          },
          onLoadStart: (controller, url) {
            _logDebug('🌐 WebView carga iniciada');
            if (mounted) setState(() => _isLoading = true);
          },
          onLoadStop: (controller, url) {
            _logDebug('🌐 WebView carga completada (${_formatElapsed(_loadStartTime)})');
            if (!mounted) return;
            setState(() => _isLoading = false);
            // Check if the page redirected to a block page (anti-framekill)
            if (url.toString().contains('/block.html')) {
              _logDebug('🚫 Página redirigió a block.html, intentando fallback...');
              _tryFallbackStream();
              return;
            }
            if (widget.adBlockerEnabled) {
              _blockAdsAndPopups(controller);
            }
            // Also enhance the stream player (autoplay, fullscreen)
            _enhanceStreamPlayer(controller);
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final url = navigationAction.request.url.toString();
            if (_isBlockedAdUrl(url)) {
              _logDebug('🚫 Navegación bloqueada: ${_truncateUrl(url)}');
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onCreateWindow: (controller, createWindowRequest) async {
            _logDebug('🚫 Popup bloqueado');
            return false;
          },
          onReceivedError: (controller, request, error) {
            if (!mounted) return;
            final desc = error.description.isNotEmpty
                ? error.description
                : 'Error desconocido';
            _logDebug('❌ WebView error: $desc');
            // Renderer crash — WebView is dead, skip reconnect and go to fallback
            if (desc.contains('crash') || desc.contains('kill') || request.isForMainFrame == false) {
              _tryFallbackStream();
              return;
            }
            setState(() {
              _isLoading = false;
              _errorMessage = 'Error al cargar: $desc';
            });
            _tryAutoReconnect();
          },
        ),

        // Loading overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0E1A).withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        strokeWidth: 3,
                        color: Colors.white54,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Cargando stream...',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    if (_progress > 0) ...[
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toInt()}%',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Error banner
        if (_errorMessage.isNotEmpty)
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: GlassContainer(
              borderRadius: 12,
              blur: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
              borderColor: Colors.orange.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orangeAccent),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Reintentar',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),

        // Progress bar
        if (_progress < 1.0 && _progress > 0 && !_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white38),
              minHeight: 2,
            ),
          ),

        // Debug overlay (on top of everything)
        if (_showDebugOverlay) _buildDebugOverlay(),
      ],
    );
  }

  void _blockAdsAndPopups(InAppWebViewController controller) async {
    if (!widget.adBlockerEnabled) return;
    // Safety net: re-add ad-block JS at onLoadStop (in case DOCUMENT_START was too early)
    try {
      await controller.evaluateJavascript(source: _postLoadAdBlockScript);
    } catch (e) {
      debugPrint('Ad-block post-load injection error: $e');
    }
  }

  /// JS injected at onLoadStop as a safety net to block ads that may have
  /// been dynamically added after page load or that slipped through DOCUMENT_START.
  static const String _postLoadAdBlockScript = r'''
    (function() {
      // Block any new window creations
      window.open = function(url) {
        if (!url) return null;
        var u = url.toLowerCase();
        if (u.indexOf('doubleclick')!==-1||u.indexOf('exoclick')!==-1||
            u.indexOf('popunder')!==-1||u.indexOf('popads')!==-1||
            u.indexOf('propeller')!==-1||u.indexOf('histats')!==-1) return null;
        return null;
      };

      // Remove any ad elements that exist
      var adDomains = ['doubleclick','exoclick','popads','popunder','propeller',
                       'adsterra','clickadu','histats','adservice','googlead'];
      setInterval(function(){
        document.querySelectorAll('iframe,script,ins.adsbygoogle').forEach(function(f){
          try{
            var s=(f.src||f.getAttribute('src')||'').toLowerCase();
            for (var i=0;i<adDomains.length;i++) {
              if (s.indexOf(adDomains[i])!==-1) { f.remove(); break; }
            }
          }catch(e){}
        });
      }, 1000);
    })();
  ''';

  /// JS injected at DOCUMENT_START to defeat anti-framekill scripts and block ads
  /// before the page's own JavaScript runs.
  static const String _adBlockUserScript = r'''
    (function() {
      // ── Anti-anti-framekill ──
      // Prevent the page from detecting it's inside a WebView/iframe
      try {
        // Block frameElement detection that causes crashes on sudamericaplay2.com
        Object.defineProperty(window, 'frameElement', { value: null, configurable: false });
        Object.defineProperty(window, 'parent', { value: window, configurable: false });
        Object.defineProperty(window, 'top', { value: window, configurable: false });
        // Block sandbox detection
        document.hasAttribute = function() { return false; };
        try { document.domain = document.domain; } catch(e) {}
      } catch(e) {}

      // ── Ad Blocker ──
      var _origOpen = window.open;
      window.open = function(url) {
        if (!url) return null;
        var u = url.toLowerCase();
        if (u.indexOf('doubleclick')!==-1||u.indexOf('exoclick')!==-1||
            u.indexOf('popunder')!==-1||u.indexOf('popads')!==-1||
            u.indexOf('propeller')!==-1||u.indexOf('histats')!==-1||
            u.indexOf('adsterra')!==-1||u.indexOf('clickadu')!==-1) return null;
        return _origOpen ? _origOpen.apply(this, arguments) : null;
      };
      window.openDialog = function() { return null; };
      window.showModalDialog = function() { return null; };

      // Block navigations to ad/block pages
      var _pushState = history.pushState;
      history.pushState = function() {
        var url = arguments[2] || '';
        if (url.indexOf('block.html') !== -1) { return; }
        return _pushState.apply(this, arguments);
      };

      // Remove ad iframes as soon as they appear (before they load)
      var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(m) {
          m.addedNodes.forEach(function(n) {
            if (n.tagName === 'IFRAME' || n.tagName === 'SCRIPT') {
              var s = (n.src || n.getAttribute('src') || '').toLowerCase();
              if (s.indexOf('doubleclick')!==-1||s.indexOf('exoclick')!==-1||
                  s.indexOf('popads')!==-1||s.indexOf('histats')!==-1||
                  s.indexOf('propeller')!==-1||s.indexOf('adsterra')!==-1||
                  s.indexOf('clickadu')!==-1||s.indexOf('adservice')!==-1) {
                n.remove();
              }
            }
          });
        });
      });
      observer.observe(document.documentElement, { childList: true, subtree: true });
    })();
  ''';

  void _enhanceStreamPlayer(InAppWebViewController controller) async {
    const script = '''
    (function() {
      // Attempt autoplay on all videos — respect browser autoplay policy (leave muted)
      document.querySelectorAll('video').forEach(function(v){
        if (v.paused) {
          v.play().catch(function(){
            // If autoplay blocked, try muted autoplay (browser policy)
            v.muted = true;
            v.play().catch(function(){});
            // Try to unmute after user gesture
            document.addEventListener('click', function() { v.muted = false; }, {once: true});
          });
        }
      });

      // Gentle CSS — no !important on body, let the player keep its layout
      var s=document.createElement('style');
      s.textContent='video,.video-js,.jwplayer,.plyr,.flowplayer{max-width:100%;max-height:100%;width:100%;height:auto;object-fit:contain}html,body{margin:0;padding:0;background:#000;overflow-x:hidden}*{-webkit-tap-highlight-color:transparent;user-select:none}';
      document.head.appendChild(s);

      // Only hide known intrusive overlays — not generic ones that may be player controls
      document.querySelectorAll('.cookie-notice,.notification-bar').forEach(function(e){e.style.display='none'});
    })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint('Stream enhancement error: $e');
    }
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _progress = 0;
      _isReconnecting = false;
      _isChangingQuality = false;
    });

    if (_isMediaStream) {
      _mediaPlayer?.dispose();
      _mediaPlayer = null;
      _videoController = null;
      _initMediaPlayer();
    } else if (_isWebView) {
      _webViewController?.reload();
      _loadingTimer?.cancel();
      _loadingTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _tryAutoReconnect();
          }
        }
      });
    }
  }

  static const _blockedAdDomains = <String>{
    'doubleclick.net',
    'googlesyndication.com',
    'pagead2.googlesyndication.com',
    'ads.google.com',
    'adservice.google.com',
    'google-analytics.com',
    'analytics.google.com',
    'connect.facebook.net',
    'amazon-adsystem.com',
    'criteo.net',
    'criteo.com',
    'outbrain.com',
    'taboola.com',
    'viglink.com',
    'everesttech.net',
    'scorecardresearch.com',
    'tracking.publishersperksservices.com',
    'adnxs.com',
    'rubicdn.com',
    'exoclick.com',
    'popads.net',
    'propellerads.com',
    'adsterra.com',
    'clickadu.com',
    'adbucks.net',
    'trafficfactory.biz',
  };

  bool _isBlockedAdUrl(String urlStr) {
    try {
      final uri = Uri.parse(urlStr);
      final host = uri.host.toLowerCase();
      // Exact match or subdomain match against known ad domains
      for (final domain in _blockedAdDomains) {
        if (host == domain || host.endsWith('.$domain')) return true;
      }
    } catch (_) {}
    return false;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// A single debug log entry with timestamp and color coding
class _DebugLogEntry {
  final String message;
  final DateTime timestamp;

  _DebugLogEntry(this.message) : timestamp = DateTime.now();

  String get formatted {
    final t = '${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${(timestamp.millisecond % 1000).toString().padLeft(3, '0')}';
    return '$t $message';
  }

  Color get color {
    if (message.startsWith('❌')) return Colors.red[300]!;
    if (message.startsWith('⚠️')) return Colors.orange[300]!;
    if (message.startsWith('🚫')) return Colors.red[200]!;
    if (message.startsWith('▶️') || message.startsWith('✅')) return Colors.green[300]!;
    if (message.startsWith('🔄')) return Colors.cyan[300]!;
    if (message.startsWith('🎯') || message.startsWith('🎬')) return Colors.amber[200]!;
    if (message.startsWith('🌐')) return Colors.lightBlue[200]!;
    if (message.startsWith('⏳')) return Colors.yellow[200]!;
    if (message.startsWith('⏹️')) return Colors.grey[400]!;
    return Colors.white70;
  }
}

/// Quality option model
class _QualityOption {
  final String label;
  final String description;
  final IconData icon;
  final String buildUrl;

  const _QualityOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.buildUrl,
  });
}

/// Quality selector bottom sheet
class _QualitySheet extends StatelessWidget {
  final String currentQuality;
  final List<_QualityOption> availableQualities;
  final ValueChanged<String> onSelect;

  const _QualitySheet({
    required this.currentQuality,
    required this.availableQualities,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2128), Color(0xFF0D1117)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  const Icon(Icons.high_quality_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Calidad de video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Seleccioná la calidad del stream',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              // Quality options
              ...availableQualities.map((q) => _buildOption(context, q)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, _QualityOption q) {
    final isSelected = q.label == currentQuality;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isSelected ? null : () => onSelect(q.label),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              width: isSelected ? 1.2 : 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    q.icon,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        q.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkmark
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF0D1117),
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
