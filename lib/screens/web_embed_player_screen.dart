import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebEmbedPlayerScreen extends StatefulWidget {
  const WebEmbedPlayerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<WebEmbedPlayerScreen> createState() => _WebEmbedPlayerScreenState();
}

class _WebEmbedPlayerScreenState extends State<WebEmbedPlayerScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() => _loadingProgress = 100);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _loadingProgress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
