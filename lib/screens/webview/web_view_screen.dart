import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_colors.dart';

/// In-App Fullscreen WebView screen for displaying legal policies
/// (Privacy Policy, Terms of Service, EULA) directly inside the app.
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? fallbackHtml;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.fallbackHtml,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showingFallback = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _isLoading = progress < 100;
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
            if (mounted && (error.isForMainFrame ?? true)) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      );

    _loadContent();
  }

  void _loadContent() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _showingFallback = false;
    });

    final targetUrl = widget.url.trim();
    if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
      _controller.loadRequest(Uri.parse(targetUrl));
    } else if (widget.fallbackHtml != null && widget.fallbackHtml!.isNotEmpty) {
      _loadFallback();
    } else {
      _controller.loadRequest(Uri.parse("https://lovia-api.genxappstudio.cloud/privacy"));
    }
  }

  void _loadFallback() {
    if (widget.fallbackHtml == null || widget.fallbackHtml!.isEmpty) return;
    setState(() {
      _showingFallback = true;
      _hasError = false;
      _isLoading = false;
    });

    final styledHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body {
      background-color: #090A10;
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 20px 16px 40px;
      line-height: 1.6;
    }
    h1 { color: #FFF; font-size: 20px; font-weight: 800; margin-bottom: 12px; }
    h2 { color: #FF66A1; font-size: 16px; font-weight: 700; margin-top: 20px; margin-bottom: 8px; }
    p, li { color: #CBD5E1; font-size: 14px; }
    ul { margin-left: 18px; margin-bottom: 14px; }
    strong { color: #FFF; }
  </style>
</head>
<body>
  ${widget.fallbackHtml ?? ''}
</body>
</html>
''';
    _controller.loadHtmlString(styledHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight, size: 22),
            tooltip: "Reload page",
            onPressed: _loadContent,
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.5),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100.0 : null,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 2.5,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Error Overlay State
          if (_hasError && !_showingFallback)
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceLight,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.primaryLight),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Unable to Load Document",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please check your internet connection or try reloading.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loadContent,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                        ),
                        if (widget.fallbackHtml != null && widget.fallbackHtml!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _loadFallback,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.glassBorder),
                              foregroundColor: AppColors.primaryLight,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text("View Offline"),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
