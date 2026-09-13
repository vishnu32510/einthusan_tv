import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class TvBrowserScreen extends StatefulWidget {
  const TvBrowserScreen({super.key});

  @override
  State<TvBrowserScreen> createState() => _TvBrowserScreenState();
}

class _TvBrowserScreenState extends State<TvBrowserScreen>
    with SingleTickerProviderStateMixin {
  static const String initialUrl =
      'https://einthusan.tv/movie/browse/?lang=tamil';

  WebViewController? _controller;
  final FocusNode _focusNode = FocusNode();

  // Page Loading State
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String? _errorMessage;

  // Virtual Cursor State
  Offset _cursorPos = const Offset(400, 300);
  bool _isClicking = false;
  bool _isCursorMode = true; // true: Virtual Cursor, false: Direct Scroll
  double _cursorSpeed = 16.0; // Base speed per tick
  Timer? _moveTimer;
  final Set<LogicalKeyboardKey> _activeDirectionKeys = {};

  // Toolbar state
  bool _showToolbar = false;
  double _zoomLevel = 1.0;
  DateTime? _lastBackPressTime;

  // Custom Desktop/TV User-Agent
  static const String tvDesktopUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  // Account Credentials for Background Auto-Login & 10-minute Lock Bypass (loaded from .env)
  static String get _accountEmail {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['EINTHUSAN_EMAIL']?.trim() ?? '';
  }

  static String get _accountPassword {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['EINTHUSAN_PASSWORD']?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeWebView();
      _startMovementLoop();
    }
  }

  void _initializeWebView() {
    if (kIsWeb) return;
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    if (!kIsWeb) {
      try {
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      } catch (_) {}

      try {
        controller.setUserAgent(tvDesktopUserAgent);
      } catch (_) {}

      try {
        controller.setBackgroundColor(const Color(0xFF0D1117));
      } catch (_) {}

      try {
        controller.setNavigationDelegate(
          NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectTvOptimizations();
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Unable to load Einthusan (${error.description}).\nPlease check your internet connection.';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              final host = uri.host.toLowerCase();

              // Whitelist allowed legitimate domains
              final isAllowed = host.contains('einthusan') ||
                  host.contains('accounts.google') ||
                  host.contains('facebook.com') ||
                  host.contains('gstatic.com') ||
                  request.url.startsWith('about:blank');

              // Blacklist known ad / popunder / redirect networks
              final isAdDomain = host.contains('doubleclick') ||
                  host.contains('googlesyndication') ||
                  host.contains('adnxs') ||
                  host.contains('vntsm') ||
                  host.contains('inmobi') ||
                  host.contains('getpublica') ||
                  host.contains('popads') ||
                  host.contains('onclick') ||
                  host.contains('adsterra') ||
                  host.contains('propeller') ||
                  host.contains('bet365') ||
                  host.contains('adservice') ||
                  host.contains('traffic');

              if (!isAllowed || isAdDomain) {
                // Block navigation to external ad / popunder URL
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      );
      } catch (_) {}
    } else {
      // Web platforms finish loading once iframe URL is assigned
      _isLoading = false;
    }
    controller.loadRequest(Uri.parse(initialUrl));

    // Enable hardware acceleration & media playback for Android
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      ).setAcceptThirdPartyCookies(androidController, true);
    }

    _controller = controller;
  }


  Future<void> _safeRunJavaScript(String script) async {
    if (kIsWeb) return;
    try {
      if (_controller != null) await _controller!.runJavaScript(script);
    } catch (_) {}
  }

  Future<bool> _safeCanGoBack() async {
    if (kIsWeb) return false;
    try {
      if (_controller == null) return false;
    return await _controller!.canGoBack();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeCanGoForward() async {
    if (kIsWeb) return false;
    try {
      if (_controller == null) return false;
    return await _controller!.canGoForward();
    } catch (_) {
      return false;
    }
  }

  void _safeGoBack() {
    if (kIsWeb) return;
    try {
      _controller?.goBack();
    } catch (_) {}
  }

  void _safeGoForward() {
    if (kIsWeb) return;
    try {
      _controller?.goForward();
    } catch (_) {}
  }

  void _safeReload() {
    if (kIsWeb) {
      _controller?.loadRequest(Uri.parse(initialUrl));
      return;
    }
    try {
      _controller?.reload();
    } catch (_) {}
  }

  /// Inject CSS & JS optimizations for TV display (ad-blocking, 10-ft TV layout, auto-fullscreen video)
  void _injectTvOptimizations() {
    if (kIsWeb) return;
    _safeRunJavaScript('''
      (function() {
        // 1. Intercept window.open: allow legitimate auth/einthusan links, KILL ad popups
        window.open = function(url) {
          if (url) {
            var lower = url.toLowerCase();
            if (lower.includes('einthusan') || lower.includes('google.com') || lower.includes('facebook.com')) {
              window.location.href = url;
            }
          }
          return null;
        };

        // 2. Ensure target=_blank links open in this webview
        document.querySelectorAll('a[target="_blank"]').forEach(function(a) {
          a.setAttribute('target', '_self');
        });

        // 3. Inject TV-Optimized Stylesheet: strip ads, enlarge posters, add TV hover glow
        var style = document.getElementById('tv-optimized-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'tv-optimized-style';
          style.innerHTML = [
            '/* Hide all ad containers and junk clutter */',
            '.adspace-lb, [id*="venatus"], [class*="adspace"], [data-id*="goadx"],',
            '#discount-offer-popup, #premium-notif-popup,',
            '.qc-cmp2-container, #cmp-modal, iframe[src*="ad"] {',
            '  display: none !important;',
            '  height: 0 !important;',
            '  max-height: 0 !important;',
            '  opacity: 0 !important;',
            '  pointer-events: none !important;',
            '}',
            '/* TV Smooth Scrolling */',
            'html, body {',
            '  scroll-behavior: smooth !important;',
            '  background-color: #0d1117 !important;',
            '}',
            '/* Enlarge Movie Cards & Posters for 10-foot TV viewing */',
            'ul li a img {',
            '  border-radius: 10px !important;',
            '  transition: transform 0.22s ease, box-shadow 0.22s ease !important;',
            '}',
            'ul li:hover img, ul li:focus-within img {',
            '  transform: scale(1.08) !important;',
            '  box-shadow: 0 8px 24px rgba(229, 9, 20, 0.75), 0 0 12px rgba(255, 255, 255, 0.4) !important;',
            '}',
            '/* TV Navigation bar clarity */',
            '#UIHeadBar {',
            '  position: sticky !important;',
            '  top: 0 !important;',
            '  z-index: 99999 !important;',
            '  box-shadow: 0 4px 16px rgba(0,0,0,0.8) !important;',
            '}',
            '/* Movie Video Player Fullscreen Enhancement */',
            '#UIVideoPlayer, .video-js, video {',
            '  max-width: 100vw !important;',
            '  width: 100% !important;',
            '  border-radius: 8px !important;',
            '}'
          ].join('\n');
          document.head.appendChild(style);
        }

        // 4. If on a movie watch page, auto-scroll directly into the video player
        var videoEl = document.querySelector('video') || document.getElementById('UIVideoPlayer');
        if (videoEl) {
          setTimeout(function() {
            videoEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }, 600);
        }

        // 5. Continuous MutationObserver: actively search and remove dynamically inserted ads
        var adSelectors = [
          '.adspace-lb', '[id*="venatus"]', '[class*="adspace"]', '[data-id*="goadx"]',
          '.qc-cmp2-container', '#cmp-modal', 'iframe[src*="ad"]', 'iframe[src*="sync"]'
        ];
        function purgeAds() {
          adSelectors.forEach(function(sel) {
            document.querySelectorAll(sel).forEach(function(node) {
              node.remove();
            });
          });
        }
        purgeAds();
        try {
          var observer = new MutationObserver(purgeAds);
          observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
        } catch(e) {}

        // 6. Auto dismiss cookie consent / GDPR banners if present
        var cmpButtons = document.querySelectorAll('button[class*="agree"], button[id*="agree"], .qc-cmp2-summary-buttons button');
        if (cmpButtons.length > 0) {
          cmpButtons[0].click();
        }

        // 7. Background Auto-Login & 10-Minute Playback Watchdog
        var accountEmail = '$_accountEmail';
        var accountPass = '$_accountPassword';

        function checkAndPerformLogin() {
          if (!accountEmail || !accountPass) return;
          var userPopup = document.getElementById('login-popup');
          var isLoggedOut = !userPopup || !userPopup.getAttribute('data-user') || userPopup.getAttribute('data-user') === '';
          var emailInput = document.getElementById('login-email');
          var passInput = document.getElementById('login-password');
          var submitBtn = document.getElementById('login-submit');

          if (isLoggedOut && emailInput && passInput && submitBtn) {
            emailInput.value = accountEmail;
            passInput.value = accountPass;
            emailInput.dispatchEvent(new Event('change', { bubbles: true }));
            passInput.dispatchEvent(new Event('input', { bubbles: true }));
            submitBtn.click();
            setTimeout(function() {
              if (window.\$ && window.\$.magnificPopup) {
                window.\$.magnificPopup.close();
              }
            }, 600);
          }
        }

        // Proactive login on initial page load if not authenticated
        checkAndPerformLogin();

        // Continuous Watchdog (every 1.5s):
        // Automatically clears 10-min login interruptions, dismisses promo modals & resumes playback
        setInterval(function() {
          // A. If login popup is triggered (e.g. at 10 minute mark)
          var loginPopup = document.getElementById('login-popup');
          if (loginPopup) {
            var isVisible = loginPopup.classList.contains('mfp-ready') ||
                            loginPopup.style.display === 'block' ||
                            !loginPopup.classList.contains('mfp-hide');
            if (isVisible) {
              checkAndPerformLogin();
              if (window.\$ && window.\$.magnificPopup) {
                window.\$.magnificPopup.close();
              }
            }
          }

          // B. Auto-dismiss discount / premium confirmation buttons
          var offerClose = document.getElementById('pn-offer-close');
          if (offerClose && offerClose.offsetParent !== null) offerClose.click();

          var premUnderstand = document.getElementById('pn-understand');
          if (premUnderstand && premUnderstand.offsetParent !== null) premUnderstand.click();

          var premClose = document.getElementById('pn-close');
          if (premClose && premClose.offsetParent !== null) premClose.click();

          // C. Auto-resume video if paused by an overlay / popup
          var video = document.querySelector('video') || document.getElementById('UIVideoPlayer');
          if (video && video.paused && !video.ended && video.currentTime > 5) {
            var blocking = document.querySelector('.mfp-wrap, .mfp-bg');
            if (blocking) {
              if (window.\$ && window.\$.magnificPopup) {
                window.\$.magnificPopup.close();
              }
              blocking.remove();
              video.play().catch(function(e) {});
            }
          }
        }, 1500);
      })();
    ''');
    _applyZoom();
  }

  /// Manually trigger background auto-login
  void _triggerAutoLogin({bool showToast = false}) {
    if (_accountEmail.isEmpty || _accountPassword.isEmpty) {
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No credentials found in .env file'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (kIsWeb) return;
    _safeRunJavaScript('''
      (function() {
        var emailInput = document.getElementById('login-email');
        var passInput = document.getElementById('login-password');
        var submitBtn = document.getElementById('login-submit');
        if (emailInput && passInput && submitBtn) {
          emailInput.value = '$_accountEmail';
          passInput.value = '$_accountPassword';
          emailInput.dispatchEvent(new Event('change', { bubbles: true }));
          passInput.dispatchEvent(new Event('input', { bubbles: true }));
          submitBtn.click();
          setTimeout(function() {
            if (window.\$ && window.\$.magnificPopup) {
              window.\$.magnificPopup.close();
            }
          }, 600);
        } else {
          window.location.href = 'https://einthusan.tv/login/?lang=tamil';
        }
      })();
    ''');
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-logging in as $_accountEmail...'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyZoom() {
    if (kIsWeb) return;
    _safeRunJavaScript('''
      document.body.style.zoom = '$_zoomLevel';
    ''');
  }

  /// Continuous ticker for smooth virtual cursor motion
  void _startMovementLoop() {
    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isCursorMode || _activeDirectionKeys.isEmpty || !mounted) return;

      double dx = 0;
      double dy = 0;

      if (_activeDirectionKeys.contains(LogicalKeyboardKey.arrowLeft)) {
        dx -= _cursorSpeed;
      }
      if (_activeDirectionKeys.contains(LogicalKeyboardKey.arrowRight)) {
        dx += _cursorSpeed;
      }
      if (_activeDirectionKeys.contains(LogicalKeyboardKey.arrowUp)) {
        dy -= _cursorSpeed;
      }
      if (_activeDirectionKeys.contains(LogicalKeyboardKey.arrowDown)) {
        dy += _cursorSpeed;
      }

      if (dx == 0 && dy == 0) return;

      final screenSize = MediaQuery.of(context).size;
      final newX = (_cursorPos.dx + dx).clamp(10.0, screenSize.width - 10.0);
      final newY = (_cursorPos.dy + dy).clamp(10.0, screenSize.height - 10.0);

      // Auto-scroll when pointer pushes against edges
      if (newY >= screenSize.height - 20) {
        _scrollPage(220);
      } else if (newY <= 20) {
        _scrollPage(-220);
      }

      // Auto reveal toolbar if pushing into top edge
      if (newY <= 15 && !_showToolbar) {
        setState(() {
          _showToolbar = true;
        });
      }

      setState(() {
        _cursorPos = Offset(newX, newY);
      });
    });
  }

  void _scrollPage(int yDelta) {
    _safeRunJavaScript('window.scrollBy({top: $yDelta, behavior: "smooth"});');
  }

  /// Simulate a click at the virtual cursor's current on-screen location
  Future<void> _simulateClick() async {
    setState(() => _isClicking = true);

    // Convert flutter screen coords to CSS webview coords
    final x = _cursorPos.dx.toInt();
    final y = _cursorPos.dy.toInt();

    final clickScript = '''
      (function() {
        var x = $x;
        var y = $y;
        var el = document.elementFromPoint(x, y);
        if (el) {
          el.focus();
          ['mouseenter', 'mouseover', 'mousedown', 'mouseup', 'click'].forEach(function(eventName) {
            var evt = new MouseEvent(eventName, {
              view: window,
              bubbles: true,
              cancelable: true,
              clientX: x,
              clientY: y
            });
            el.dispatchEvent(evt);
          });
          var anchor = el.closest('a');
          if (anchor && anchor.href && !anchor.href.startsWith('javascript:')) {
            window.location.href = anchor.href;
          }
        }
      })();
    ''';

    await _safeRunJavaScript(clickScript);

    await Future.delayed(const Duration(milliseconds: 160));
    if (mounted) {
      setState(() => _isClicking = false);
    }
  }

  /// Handle TV Remote Key events
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Detect direction keys
    final isDirectionKey = key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    if (event is KeyDownEvent) {
      // Menu key toggles toolbar
      if (key == LogicalKeyboardKey.contextMenu ||
          key == LogicalKeyboardKey.info ||
          key == LogicalKeyboardKey.help) {
        setState(() {
          _showToolbar = !_showToolbar;
        });
        return KeyEventResult.handled;
      }

      // Enter / Select / D-pad Center
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.gameButtonA) {
        if (_showToolbar) {
          // Let toolbar handle its own focus
          return KeyEventResult.ignored;
        }
        if (_isCursorMode) {
          _simulateClick();
        } else {
          // In direct scroll mode, select acts as click at center
          _simulateClick();
        }
        return KeyEventResult.handled;
      }

      // Direct Scroll Mode handlers
      if (!_isCursorMode && isDirectionKey) {
        if (key == LogicalKeyboardKey.arrowDown) {
          _scrollPage(300);
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _scrollPage(-300);
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _safeCanGoBack().then((can) {
            if (can) _safeGoBack();
          });
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _safeCanGoForward().then((can) {
            if (can) _safeGoForward();
          });
          return KeyEventResult.handled;
        }
      }

      // Cursor Mode direction keys
      if (_isCursorMode && isDirectionKey) {
        _activeDirectionKeys.add(key);
        return KeyEventResult.handled;
      }

      // Media keys (Play/Pause)
      if (key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.mediaPause) {
        _controller?.runJavaScript('''
          (function() {
            var v = document.querySelector('video');
            if (v) {
              if (v.paused) { v.play(); } else { v.pause(); }
            }
          })();
        ''');
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (isDirectionKey) {
        _activeDirectionKeys.remove(key);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Handle Back button press on TV remote
  Future<bool> _handleWillPop() async {
    if (_showToolbar) {
      setState(() => _showToolbar = false);
      return false;
    }

    final canGoBack = _controller != null && await _controller!.canGoBack();
    if (canGoBack) {
      await _controller?.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press BACK again to exit Einthusan TV'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1F2937),
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebHub(context);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Stack(
            children: [
              // Main WebView
              Positioned.fill(
                child: _controller != null ? WebViewWidget(controller: _controller!) : const SizedBox.shrink(),
              ),

              // Loading Progress Bar
              if (_isLoading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    color: const Color(0xFFE50914),
                  ),
                ),

              // Error Overlay
              if (_errorMessage != null)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF0D1117).withValues(alpha: 0.96),
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 72,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connection Issue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _controller?.reload();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // TV Overlay Toolbar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: _showToolbar ? 0 : -90,
                left: 0,
                right: 0,
                child: _buildTvToolbar(),
              ),

              // Virtual Cursor
              if (_isCursorMode && _errorMessage == null)
                Positioned(
                  left: _cursorPos.dx - 14,
                  top: _cursorPos.dy - 14,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: _isClicking ? 0.75 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isClicking
                              ? const Color(0xFFE50914).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.85),
                          border: Border.all(
                            color: _isClicking ? Colors.white : Colors.black,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isClicking ? Colors.white : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Top edge pull hint / Toolbar toggle hotspot
              Positioned(
                top: 0,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showToolbar = !_showToolbar);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showToolbar
                              ? Icons.keyboard_arrow_up
                              : Icons.menu_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showToolbar ? 'Hide Bar' : 'Menu / Bar',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// TV Navigation Toolbar
  Widget _buildTvToolbar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF30363D), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Logo & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.movie_filter_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'EINTHUSAN TV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Navigation buttons
          _buildToolbarButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onTap: () async {
              if (await _safeCanGoBack()) {
                _safeGoBack();
              }
            },
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Forward',
            onTap: () async {
              if (await _safeCanGoForward()) {
                _safeGoForward();
              }
            },
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.refresh_rounded,
            label: 'Reload',
            onTap: () => _safeReload(),
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.home_rounded,
            label: 'Tamil Home',
            onTap: () => _controller?.loadRequest(Uri.parse(initialUrl)),
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.verified_user_rounded,
            label: _accountEmail.isNotEmpty ? 'Auto-Login (${_accountEmail.split("@").first})' : 'Login',
            color: const Color(0xFF10B981),
            onTap: () => _triggerAutoLogin(showToast: true),
          ),

          const SizedBox(width: 32),

          // Mode Switch (Cursor vs Direct Scroll)
          _buildToolbarButton(
            icon: _isCursorMode
                ? Icons.mouse_rounded
                : Icons.swap_vert_rounded,
            label: _isCursorMode ? 'Cursor Mode' : 'Scroll Mode',
            color: _isCursorMode
                ? const Color(0xFF3B82F6)
                : const Color(0xFF10B981),
            onTap: () {
              setState(() {
                _isCursorMode = !_isCursorMode;
              });
            },
          ),
          const SizedBox(width: 8),

          // Cursor Speed Switcher
          if (_isCursorMode)
            _buildToolbarButton(
              icon: Icons.speed_rounded,
              label: '${_cursorSpeed == 10.0 ? "1x" : _cursorSpeed == 16.0 ? "1.5x" : "2.5x"} Speed',
              onTap: () {
                setState(() {
                  if (_cursorSpeed == 10.0) {
                    _cursorSpeed = 16.0;
                  } else if (_cursorSpeed == 16.0) {
                    _cursorSpeed = 26.0;
                  } else {
                    _cursorSpeed = 10.0;
                  }
                });
              },
            ),
          const SizedBox(width: 8),

          // Zoom Out
          _buildToolbarButton(
            icon: Icons.zoom_out_rounded,
            label: 'Zoom -',
            onTap: () {
              setState(() {
                _zoomLevel = (_zoomLevel - 0.1).clamp(0.7, 1.5);
              });
              _applyZoom();
            },
          ),
          const SizedBox(width: 8),

          // Zoom In
          _buildToolbarButton(
            icon: Icons.zoom_in_rounded,
            label: 'Zoom +',
            onTap: () {
              setState(() {
                _zoomLevel = (_zoomLevel + 0.1).clamp(0.7, 1.5);
              });
              _applyZoom();
            },
          ),
          const SizedBox(width: 12),

          // Close bar
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Hide Toolbar',
            onPressed: () {
              setState(() => _showToolbar = false);
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF21262D)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('Error launching url: $e');
    }
  }

  Widget _buildWebHub(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF131D33),
              Color(0xFF090D18),
              Color(0xFF04060B),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 48,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Navbar
                  _buildWebNav(context, isMobile),
                  const SizedBox(height: 48),

                  // Hero Emblem & Brand
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hero Titles
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFE2E8F0)],
                    ).createShader(bounds),
                    child: const Text(
                      'Einthusan Cinema',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Direct HD Streaming for Tamil, Telugu, Hindi, Malayalam & Kannada Movies',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Primary Launch CTA Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _openUrl(initialUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Launch Einthusan Web Player',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 20,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Language Quick-Jump Bar
                  _buildLanguagePicker(isMobile),
                  const SizedBox(height: 48),

                  // Frame-Options Technical Notice Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D30).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2E3E5C).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF38BDF8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Why does the web player launch in a secure window?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Einthusan’s media servers enforce strict "X-Frame-Options: DENY" HTTP headers to prevent unauthorized embedded iframes in web browsers. Launching directly in a top-level window bypasses iframe connection errors and delivers uninterrupted full-resolution hardware video acceleration.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Smart TV App Promotion Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E293B).withValues(alpha: 0.7),
                          const Color(0xFF0F172A).withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF334155).withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.tv_rounded,
                                color: Color(0xFF10B981),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Watch on Android TV & Firestick',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Enjoy true 10-foot television remote control navigation with a built-in virtual mouse cursor, ad & popunder filtering, and continuous playback on Google TV, Sony Bravia, Xiaomi, and Amazon Fire TV.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text(
                                'Download Android TV APK',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _openUrl(
                                'https://github.com/vishnu32510/einthusan_tv/releases',
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE2E8F0),
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.code_rounded),
                              label: const Text('GitHub Source'),
                              onPressed: () => _openUrl(
                                'https://github.com/vishnu32510/einthusan_tv',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 56),

                  // Legal Footer
                  _buildWebFooter(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebNav(BuildContext context, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE50914).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'NUNGU TV',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'WEB HUB',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        if (!isMobile)
          Row(
            children: [
              TextButton(
                onPressed: () => _openUrl('terms.html'),
                child: const Text(
                  'Terms & DMCA',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _openUrl('privacy.html'),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLanguagePicker(bool isMobile) {
    final languages = [
      {'name': 'Tamil', 'code': 'tamil'},
      {'name': 'Telugu', 'code': 'telugu'},
      {'name': 'Hindi', 'code': 'hindi'},
      {'name': 'Malayalam', 'code': 'malayalam'},
      {'name': 'Kannada', 'code': 'kannada'},
      {'name': 'Bengali', 'code': 'bengali'},
    ];

    return Column(
      children: [
        const Text(
          'Quick Browse by Language',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: languages.map((lang) {
            return InkWell(
              onTap: () => _openUrl('https://einthusan.tv/movie/browse/?lang=${lang["code"]}'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2A3A54),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            InkWell(
              onTap: () => _openUrl('terms.html'),
              child: const Text(
                'Terms of Service',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            InkWell(
              onTap: () => _openUrl('terms.html#dmca'),
              child: const Text(
                'DMCA & Copyright Takedown',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            InkWell(
              onTap: () => _openUrl('privacy.html'),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            InkWell(
              onTap: () => _openUrl('https://github.com/vishnu32510/einthusan_tv'),
              child: const Text(
                'GitHub',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Nungu TV is an independent client and media portal. We do not host, store, or broadcast any video streams on our servers. All video media is streamed directly from public third-party web servers.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '© 2026 Nungu TV. All trademarks belong to their respective owners.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

}
