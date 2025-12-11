import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_state.dart';
import '../widgets/custom_titlebar.dart';
import '../widgets/welcome_page.dart';
import '../widgets/not_found_page.dart';
import '../widgets/error_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final TextEditingController _urlController = TextEditingController();
  final WebviewController _webViewController = WebviewController();
  bool _isWebViewInitialized = false;
  double _loadingProgress = 0;
  String _currentLoadedUrl = '';
  Size? _windowSize;
  bool _isToolbarVisible = true;   // 默认显示工具栏
  String? _loadError;
  bool _showNotFound = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWebView();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _urlController.text = appState.currentUrl;
      _updateWindowSize();
    });
  }

  @override
  void onWindowResize() {
    _updateWindowSize();
  }

  @override
  void onWindowMaximize() {
    _updateWindowSize();
  }

  @override
  void onWindowUnmaximize() {
    _updateWindowSize();
  }

  void _updateWindowSize() async {
    final size = await windowManager.getSize();
    if (_windowSize != size && mounted) {
      setState(() {
        _windowSize = size;
      });
      if (_isWebViewInitialized) {
        _adjustWebViewZoom();
      }
    }
  }

  void _adjustWebViewZoom() async {
    if (_windowSize != null && _isWebViewInitialized) {
      final windowWidth = _windowSize!.width;
      double zoomFactor = 1.0;
      
      // 根据窗口宽度调整缩放，确保网页内容完全显示不出现滚动条
      if (windowWidth < 1400) {
        zoomFactor = windowWidth / 1400;  // 增加基准宽度
        if (zoomFactor < 0.6) {
          zoomFactor = 0.6;  // 设置最小缩放比例
        }
      }
      
      await _webViewController.setZoomFactor(zoomFactor);
      debugPrint('窗口宽度 ${windowWidth.toInt()}px，缩放比例 ${(zoomFactor * 100).toInt()}%');
    }
  }

  Future<void> _initWebView() async {
    await _webViewController.initialize();
    setState(() => _isWebViewInitialized = true);
    
    _webViewController.loadingState.listen((state) {
      if (mounted) {
        setState(() {
          _loadingProgress = (state == LoadingState.navigationCompleted) ? 1.0 : 0.5;
        });
        
        if (state == LoadingState.navigationCompleted) {
          _onLoadComplete();
        }
      }
    });
    
    // 监听网页标题变化
    _webViewController.title.listen((title) {
      if (mounted && title.isNotEmpty) {
        debugPrint('📝 网页标题: $title');
        context.read<AppState>().updatePageTitle(title);
      }
    });
    
    _adjustWebViewZoom();
    
    // WebView初始化完成后，自动加载缓存的URL
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final appState = context.read<AppState>();
        if (appState.currentUrl.isNotEmpty) {
          debugPrint('🚀 自动加载网址: ${appState.currentUrl}');
          _currentLoadedUrl = appState.currentUrl;
          await _webViewController.loadUrl(appState.currentUrl);
        }
      }
    });
  }

  void _onLoadComplete() async {
    _adjustWebViewZoom();
    
    // 清除错误状态
    if (mounted) {
      setState(() {
        _loadError = null;
        _showNotFound = false;
      });
    }
    
    // 生成favicon URL
    if (_currentLoadedUrl.isNotEmpty && mounted) {
      final uri = Uri.parse(_currentLoadedUrl);
      final favIconUrl = '${uri.scheme}://${uri.host}/favicon.ico';
      context.read<AppState>().updateFavIcon(favIconUrl);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _urlController.dispose();
    _webViewController.dispose();
    super.dispose();
  }

  void _loadUrl(AppState appState) async {
    final url = _urlController.text.trim();
    
    if (!url.startsWith('https://')) {
      appState.setError('⚠️ 仅支持 HTTPS 网站');
      return;
    }

    try {
      appState.setLoading(true);
      appState.setError(null);
      
      setState(() {
        _loadError = null;
        _showNotFound = false;
      });
      
      await appState.saveUrl(url);
      
      if (_isWebViewInitialized && _currentLoadedUrl != url) {
        _currentLoadedUrl = url;
        
        // 启动加载监控
        _startLoadMonitor(url);
        
        await _webViewController.loadUrl(url);
      }
    } catch (e) {
      appState.setError('加载失败: $e');
      setState(() {
        _loadError = '网络连接失败';
      });
    } finally {
      appState.setLoading(false);
    }
  }

  // 启动加载监控
  void _startLoadMonitor(String url) async {
    // 等待10秒检查加载状态
    await Future.delayed(const Duration(seconds: 10));
    
    if (!mounted) return;
    
    // 如果10秒后进度还是0，说明可能网络断开或404
    if (_loadingProgress == 0) {
      setState(() {
        _loadError = '无法连接到该网址';
      });
    }
  }

  void _refresh() async {
    if (_isWebViewInitialized) {
      setState(() {
        _loadError = null;
        _showNotFound = false;
      });
      _webViewController.reload();
    }
  }

  void _goHome() {
    final appState = context.read<AppState>();
    // 不清除网址，只重置页面信息和状态
    appState.resetPageInfo();
    setState(() {
      _currentLoadedUrl = '';
      _loadError = null;
      _showNotFound = false;
    });
  }

  // 截图功能
  Future<void> _takeScreenshot() async {
    try {
      // 选择保存位置
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存截图',
        fileName: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        type: FileType.image,
      );

      if (result != null) {
        // 注意：webview_windows 不支持直接截图，需要使用其他方法
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('截图功能暂未实现，webview_windows 不支持直接截图'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('截图失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('截图失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 打印功能
  Future<void> _printPage() async {
    try {
      // webview_windows 支持打印
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('打印功能暂未实现'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('打印失败: $e');
    }
  }

  // 导出PDF
  Future<void> _exportPdf() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出PDF',
        fileName: 'export_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF导出功能暂未实现'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('导出PDF失败: $e');
    }
  }

  // 导出Markdown
  Future<void> _exportMarkdown() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出Markdown',
        fileName: 'export_${DateTime.now().millisecondsSinceEpoch}.md',
        type: FileType.custom,
        allowedExtensions: ['md'],
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Markdown导出功能暂未实现'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('导出Markdown失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: CustomTitleBar(
            onRefresh: _currentLoadedUrl.isNotEmpty ? _refresh : null,
            onHome: _currentLoadedUrl.isNotEmpty ? _goHome : null,
            onToggleUrlBar: () {
              setState(() {
                _isToolbarVisible = !_isToolbarVisible;
              });
            },
            isUrlBarVisible: _isToolbarVisible,
            pageTitle: appState.pageTitle,
            favIconUrl: appState.favIconUrl,
            hasUrl: _currentLoadedUrl.isNotEmpty,  // 传递是否有网址
          ),
          body: Column(
            children: [
              // 工具栏（独立控制）
              if (_isToolbarVisible && _currentLoadedUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildToolButton(
                        icon: Icons.print_outlined,
                        label: '打印',
                        onPressed: _printPage,
                        color: Colors.green,
                      ),
                      _buildToolButton(
                        icon: Icons.screenshot_outlined,
                        label: '截图',
                        onPressed: _takeScreenshot,
                        color: Colors.orange,
                      ),
                      _buildToolButton(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'PDF',
                        onPressed: _exportPdf,
                        color: Colors.red,
                      ),
                      _buildToolButton(
                        icon: Icons.article_outlined,
                        label: 'MD',
                        onPressed: _exportMarkdown,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              
              // 错误提示
              if (appState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appState.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => appState.setError(null),
                      ),
                    ],
                  ),
                ),
              
              // 加载进度条
              if (appState.isLoading)
                LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                ),
              
              // 主内容区域
              Expanded(
                child: _buildContent(appState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(AppState appState) {
    // 显示欢迎页
    if (appState.shouldShowWelcome) {
      return WelcomePage(
        cachedUrl: appState.currentUrl,
        onLoadCached: () {
          if (appState.currentUrl.isNotEmpty) {
            _loadUrl(appState);
          }
        },
      );
    }
    
    // 显示错误页
    if (_loadError != null) {
      return ErrorPage(
        errorMessage: _loadError!,
        url: _currentLoadedUrl,
        onRetry: _refresh,
        onGoBack: _goHome,
      );
    }
    
    // 显示404页
    if (_showNotFound) {
      return NotFoundPage(
        url: _currentLoadedUrl,
        onRetry: _refresh,
        onGoBack: _goHome,
      );
    }
    
    // 显示WebView
    if (_isWebViewInitialized) {
      return Webview(_webViewController);
    }
    
    // 初始化中
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  // 工具按钮组件
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isEnabled = onPressed != null;
    
    return Tooltip(
      message: label,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: isEnabled ? color : Colors.grey,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
