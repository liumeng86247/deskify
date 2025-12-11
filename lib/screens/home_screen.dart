import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_state.dart';
import '../services/download_service.dart';
import '../widgets/custom_titlebar.dart';
import '../widgets/welcome_page.dart';
import '../widgets/not_found_page.dart';
import '../widgets/error_page.dart';
import '../widgets/download_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final TextEditingController _urlController = TextEditingController();
  final WebviewController _webViewController = WebviewController();
  final DownloadService _downloadService = DownloadService();
  bool _isWebViewInitialized = false;
  double _loadingProgress = 0;
  String _currentLoadedUrl = '';
  Uri? _rootUri; // 当前站点的根域名（用于同域/异域判断）
  Size? _windowSize;
  String? _loadError;
  bool _showNotFound = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _downloadService.addListener(_onDownloadServiceChanged);
    _initWebView();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _urlController.text = appState.currentUrl;
      _updateWindowSize();
    });
  }

  void _onDownloadServiceChanged() {
    if (mounted) {
      setState(() {});
    }
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
    // 设置popup策略为sameWindow，方便统一拦截
    await _webViewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
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

    // 监听URL变化：处理跳转和下载
    _webViewController.url.listen((url) async {
      if (!mounted || url.isEmpty) return;

      final newUri = Uri.tryParse(url);
      if (newUri == null) return;

      // 只关心 http/https
      if (newUri.scheme != 'http' && newUri.scheme != 'https') {
        return;
      }

      // 如果还没有根域名（第一次成功导航），以当前URL为根
      _rootUri ??= newUri;

      // 判断是否是下载URL
      if (_isDownloadUrl(newUri)) {
        debugPrint('📥 检测到下载: $url');
        await _handleDownload(newUri);
        return;
      }

      // 同域：正常在WebView内导航
      if (_rootUri != null && newUri.host == _rootUri!.host) {
        _currentLoadedUrl = url;
        await context.read<AppState>().saveUrl(url);
        debugPrint('🔗 站内导航: $url');
        return;
      }

      // 异域：交给系统浏览器
      debugPrint('🌐 异域链接，使用系统浏览器: $url');
      await _openInExternalBrowser(url);

      // 把WebView拉回当前站点
      if (_currentLoadedUrl.isNotEmpty &&
          _currentLoadedUrl != url &&
          _isWebViewInitialized) {
        await _webViewController.loadUrl(_currentLoadedUrl);
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
          _rootUri = Uri.tryParse(_currentLoadedUrl);
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
    
    // 主动获取网页标题
    if (_isWebViewInitialized && mounted) {
      try {
        final titleResult = await _webViewController.executeScript(
          'document.title',
        );
        if (titleResult != null && titleResult.toString().isNotEmpty) {
          String title = titleResult.toString();
          // 移除外层引号
          if (title.startsWith('"') && title.endsWith('"')) {
            title = title.substring(1, title.length - 1);
          }
          debugPrint('📝 加载完成，获取标题: $title');
          context.read<AppState>().updatePageTitle(title);
        }
      } catch (e) {
        debugPrint('⚠️ 获取标题失败: $e');
      }
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
    _downloadService.removeListener(_onDownloadServiceChanged);
    _urlController.dispose();
    _webViewController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  /// 判断URL是否为下载链接
  bool _isDownloadUrl(Uri uri) {
    final ext = uri.path.split('.').last.toLowerCase();
    const downloadExts = [
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
      'zip', 'rar', '7z', 'tar', 'gz',
      'csv', 'txt', 'json', 'xml',
      'jpg', 'jpeg', 'png', 'gif', 'svg', 'bmp',
      'mp3', 'mp4', 'avi', 'mkv', 'mov',
      'apk', 'dmg', 'deb', 'rpm',
    ];
    return downloadExts.contains(ext);
  }

  /// 处理下载
  Future<void> _handleDownload(Uri uri) async {
    try {
      final fileName = DownloadService.getFileNameFromUrl(uri);
      
      // 可执行文件需要二次确认
      if (DownloadService.isExecutableFile(fileName)) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('安全提示'),
            content: Text('即将下载可执行文件：$fileName\n\n请确认文件来源可信。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续下载'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) return;
      }

      // 添加到下载队列
      await _downloadService.enqueue(uri);
      
      // 显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加到下载队列：$fileName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 把WebView拉回上一个页面
      if (_currentLoadedUrl.isNotEmpty && _isWebViewInitialized) {
        await _webViewController.loadUrl(_currentLoadedUrl);
      }
    } catch (e) {
      debugPrint('❌ 处理下载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 用系统浏览器打开链接
  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      debugPrint('⚠️ 无法解析为URI: $url');
      return;
    }

    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        debugPrint('⚠️ 无法在系统浏览器中打开: $url');
        return;
      }
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已在系统浏览器中打开'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 打开系统浏览器失败: $e');
    }
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
      appState.hideWelcome(); // 开始加载时隐藏欢迎页
      
      setState(() {
        _loadError = null;
        _showNotFound = false;
      });

      // 更新当前根域名为用户输入的网站
      _rootUri = Uri.tryParse(url);
      
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
    // 保留URL，但显示欢迎页
    appState.showWelcome();
    setState(() {
      _currentLoadedUrl = '';
      _loadError = null;
      _showNotFound = false;
    });
  }

  /// 打开下载管理器
  void _openDownloadManager() {
    showDialog(
      context: context,
      builder: (context) => DownloadDialog(
        downloadService: _downloadService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: CustomTitleBar(
            onRefresh: _currentLoadedUrl.isNotEmpty ? _refresh : null,
            onHome: _currentLoadedUrl.isNotEmpty ? _goHome : null,
            onDownload: _openDownloadManager,
            onToggleLanguage: () => appState.toggleLanguage(),
            pageTitle: appState.pageTitle,
            favIconUrl: appState.favIconUrl,
            hasUrl: _currentLoadedUrl.isNotEmpty,
            downloadCount: _downloadService.tasks.where((t) => 
              t.status == DownloadStatus.running || 
              t.status == DownloadStatus.pending
            ).length,
            appState: appState,
          ),
          body: Column(
            children: [
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
        onLoadUrl: (url) {
          _urlController.text = url;
          _loadUrl(appState);
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
}
