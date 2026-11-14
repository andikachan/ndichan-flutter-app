import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../constants/app_colors.dart';
import 'offline_screen.dart';

class MainWebviewScreen extends StatefulWidget {
  const MainWebviewScreen({super.key});

  static const String appUrl = 'https://ndichan.xyz';

  @override
  State<MainWebviewScreen> createState() => _MainWebviewScreenState();
}

class _MainWebviewScreenState extends State<MainWebviewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    _hasError = false;
    _isLoading = true;

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.ink)
      ..setUserAgent('NdichanMobile/1.0.67 (Android; Flutter App)')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
                if (progress == 100) {
                  _isLoading = false;
                }
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Main frame failure triggers offline view
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final uri = Uri.parse(request.url);

            // Handle non-HTTP external app schemes (e.g. WhatsApp, Telegram, mailto, tel)
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return NavigationDecision.prevent;
                }
              } catch (_) {}
              return NavigationDecision.prevent;
            }

            // Open external domains in external browser if needed
            final host = uri.host.toLowerCase();
            if (host.contains('youtube.com') ||
                host.contains('youtu.be') ||
                host.contains('telegram.org') ||
                host.contains('t.me') ||
                host.contains('twitter.com') ||
                host.contains('x.com')) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              } catch (_) {}
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    // Android-specific platform optimizations
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(false);
      androidController.setMediaPlaybackRequiresUserGesture(false);

      // Mixed Content is required so third-party video and CDN image proxies load smoothly
      androidController.setOnPlatformPermissionRequest(
        (PlatformPermissionRequest request) {
          request.grant();
        },
      );
    }

    _controller = controller;
    _controller.loadRequest(Uri.parse(MainWebviewScreen.appUrl));
  }

  Future<void> _handleRefresh() async {
    _controller.reload();
  }

  void _onBackPressed(bool didPop) async {
    if (didPop) return;

    if (await _controller.canGoBack()) {
      _controller.goBack();
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.panel,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.gold.withOpacity(0.3), width: 1),
            ),
            duration: const Duration(seconds: 2),
            content: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
                SizedBox(width: 10),
                Text(
                  'Tekan sekali lagi untuk keluar dari Ndichan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return OfflineScreen(
        onRetry: () {
          setState(() {
            _hasError = false;
            _isLoading = true;
          });
          _controller.loadRequest(Uri.parse(MainWebviewScreen.appUrl));
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onBackPressed(didPop),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              // Native RefreshIndicator wrapping the WebView
              RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.panel,
                onRefresh: _handleRefresh,
                child: WebViewWidget(controller: _controller),
              ),

              // Top Slim Gold Progress Bar during Navigation
              if (_isLoading && _loadingProgress < 100)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
