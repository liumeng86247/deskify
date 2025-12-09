import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import '../models/app_state.dart';
import '../widgets/custom_titlebar.dart';

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
  bool _isUrlBarVisible = true; // 控制地址栏显示状态

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWebView();
    // 监听URL变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _urlController.text = appState.currentUrl;
      _updateWindowSize();
    });
  }

  // 监听窗口大小变化
  @override
  void onWindowResize() {
    _updateWindowSize();
  }

  // 更新窗口大小和WebView缩放
  void _updateWindowSize() async {
    final size = await windowManager.getSize();
    if (_windowSize != size && mounted) {
      setState(() {
        _windowSize = size;
      });
      // 调整WebView缩放以适应窗口
      if (_isWebViewInitialized) {
        _adjustWebViewZoom();
      }
    }
  }

  // 调整WebView缩放比例
  void _adjustWebViewZoom() async {
    if (_windowSize != null && _isWebViewInitialized) {
      // 计算合适的缩放比例，确保内容不超出窗口
      // 使用较小的缩放值来确保内容完全可见
      double zoomFactor = 0.8; // 默认缩放到80%
      
      // 如果窗口特别小，进一步缩小
      if (_windowSize!.width < 800) {
        zoomFactor = 0.6;
      } else if (_windowSize!.width < 1000) {
        zoomFactor = 0.7;
      }
      
      // 设置缩放因子
      await _webViewController.setZoomFactor(zoomFactor);
      
      // 通过JavaScript强制页面适配窗口
      _webViewController.executeScript('''
        (function() {
          // 移除或修改viewport meta标签
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          // 设置viewport，允许缩小以适应内容
          viewport.content = 'width=device-width, initial-scale=0.8, minimum-scale=0.5, maximum-scale=2.0, user-scalable=yes';
          
          // 强制设置body和html的样式
          document.documentElement.style.maxWidth = '100vw';
          document.documentElement.style.overflowX = 'auto';
          document.body.style.maxWidth = '100vw';
          document.body.style.overflowX = 'auto';
          
          // 防止固定宽度元素超出
          var style = document.createElement('style');
          style.textContent = `
            * {
              max-width: 100% !important;
              box-sizing: border-box !important;
            }
            img, video, iframe {
              max-width: 100% !important;
              height: auto !important;
            }
          `;
          if (!document.getElementById('deskify-responsive-style')) {
            style.id = 'deskify-responsive-style';
            document.head.appendChild(style);
          }
        })();
      ''');
    }
  }

  Future<void> _initWebView() async {
    await _webViewController.initialize();
    setState(() => _isWebViewInitialized = true);
    
    // 监听加载进度
    _webViewController.loadingState.listen((state) {
      if (mounted) {
        setState(() {
          _loadingProgress = (state == LoadingState.navigationCompleted) ? 1.0 : 0.5;
        });
        // 加载完成后调整缩放
        if (state == LoadingState.navigationCompleted) {
          _adjustWebViewZoom();
        }
      }
    });
    
    // 初始化缩放
    _adjustWebViewZoom();
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
      await appState.saveUrl(url);
      
      if (_isWebViewInitialized && _currentLoadedUrl != url) {
        _currentLoadedUrl = url;
        await _webViewController.loadUrl(url);
        // 加载后隐藏地址栏
        setState(() {
          _isUrlBarVisible = false;
        });
      }
    } catch (e) {
      appState.setError('加载失败: $e');
    } finally {
      appState.setLoading(false);
    }
  }

  void _refresh() {
    if (_isWebViewInitialized) {
      _webViewController.reload();
    }
  }

  void _print() {
    // webview_windows暂不支持直接打印，使用JavaScript调用浏览器打印
    if (_isWebViewInitialized) {
      _webViewController.executeScript('window.print()');
    }
  }

 // 截长图功能 - 使用打印到PDF的方式
  void _captureFullPage() async {
    if (!_isWebViewInitialized) return;

    try {
      // 显示提示
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导出PDF'),
            content: const Text(
              '点击确定后将打开打印对话框\n\n'
              '请按照以下步骤操作：\n'
              '1️⃣ 目标打印机：选择"另存为PDF"或"Microsoft Print to PDF"\n'
              '2️⃣ 缩放：设置为"100%"或"默认"\n'
              '3️⃣ 其他设置：保持默认即可\n'
              '4️⃣ 点击"打印"按钮\n\n'
              '✅ PDF文件将包含完整的页面内容',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _executePrintToPDF();
                },
                child: const Text('开始导出'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 执行打印到PDF
  void _executePrintToPDF() async {
    try {
      await _webViewController.executeScript('''
        (function() {
          // 保存当前缩放设置
          const originalViewport = document.querySelector('meta[name="viewport"]');
          const originalViewportContent = originalViewport ? originalViewport.content : '';
          
          // 移除Deskify的响应式样式
          const deskifyStyle = document.getElementById('deskify-responsive-style');
          if (deskifyStyle) {
            deskifyStyle.remove();
          }
          
          // 临时修改页面样式以优化打印效果
          const style = document.createElement('style');
          style.id = 'print-optimization';
          style.textContent = `
            @page {
              size: auto;
              margin: 10mm;
            }
            
            @media print {
              html, body {
                width: 100% !important;
                height: auto !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow: visible !important;
                zoom: 1 !important;
                transform: none !important;
              }
              
              body {
                zoom: 1.0 !important;
                -moz-transform: scale(1.0) !important;
                -webkit-transform: scale(1.0) !important;
                transform: scale(1.0) !important;
              }
              
              * {
                max-width: 100% !important;
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
                box-sizing: border-box !important;
              }
              
              img, video, iframe {
                max-width: 100% !important;
                height: auto !important;
                page-break-inside: avoid !important;
              }
              
              /* 避免内容被截断 */
              div, section, article {
                page-break-inside: avoid !important;
              }
            }
          `;
          document.head.appendChild(style);
          
          // 临时设置viewport为打印优化
          if (originalViewport) {
            originalViewport.content = 'width=device-width, initial-scale=1.0';
          }
          
          // 临时重置body样式
          const bodyStyle = document.body.style;
          const originalMaxWidth = bodyStyle.maxWidth;
          const originalOverflowX = bodyStyle.overflowX;
          bodyStyle.maxWidth = 'none';
          bodyStyle.overflowX = 'visible';
          
          // 触发打印
          window.print();
          
          // 打印完成后恢复样式
          setTimeout(() => {
            const printStyle = document.getElementById('print-optimization');
            if (printStyle) printStyle.remove();
            
            // 恢复viewport
            if (originalViewport) {
              originalViewport.content = originalViewportContent;
            }
            
            // 恢复body样式
            bodyStyle.maxWidth = originalMaxWidth;
            bodyStyle.overflowX = originalOverflowX;
            
            // 重新应用Deskify样式
            if (!document.getElementById('deskify-responsive-style')) {
              const style = document.createElement('style');
              style.id = 'deskify-responsive-style';
              style.textContent = `
                * {
                  max-width: 100% !important;
                  box-sizing: border-box !important;
                }
                img, video, iframe {
                  max-width: 100% !important;
                  height: auto !important;
                }
              `;
              document.head.appendChild(style);
            }
          }, 1000);
        })();
      ''');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请在打印对话框中选择"另存为PDF"，并确保缩放设置为100%'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打印失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 自定义标题栏
          const CustomTitleBar(),
          
          // 工具栏
          _buildToolbar(),
          
          // 错误提示
          Consumer<AppState>(
            builder: (context, appState, _) {
              if (appState.errorMessage != null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFFFFEEEE),
                  child: Text(
                    appState.errorMessage!,
                    style: const TextStyle(color: Color(0xFFCC3333)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // 进度条
          if (_loadingProgress > 0 && _loadingProgress < 1)
            LinearProgressIndicator(value: _loadingProgress),
          
          // WebView内容区
          Expanded(
            child: _buildWebView(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isUrlBarVisible ? 56 : 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C2C2C), Color(0xFF3A3A3A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // 地址栏切换按钮
              _buildIconButton(
                icon: _isUrlBarVisible ? Icons.keyboard_arrow_up : Icons.edit,
                tooltip: _isUrlBarVisible ? '隐藏地址栏' : '显示地址栏',
                onPressed: () {
                  setState(() {
                    _isUrlBarVisible = !_isUrlBarVisible;
                  });
                },
              ),
              const SizedBox(width: 8),
              
              // URL输入框(只在显示时渲染)
              if (_isUrlBarVisible)
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF505050),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '输入HTTPS网址...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        prefixIcon: const Icon(Icons.language, size: 16, color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      onSubmitted: (_) => _loadUrl(appState),
                    ),
                  ),
                ),
              if (_isUrlBarVisible) const SizedBox(width: 8),
              
              // 打开/加载按钮
              if (_isUrlBarVisible)
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: appState.isLoading ? null : () => _loadUrl(appState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          appState.isLoading ? '加载中...' : '打开',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isUrlBarVisible) const SizedBox(width: 8),
              
              const Spacer(),
              
              // 功能按钮组
              _buildIconButton(
                icon: Icons.refresh,
                tooltip: '刷新',
                onPressed: _refresh,
              ),
              const SizedBox(width: 4),
              _buildIconButton(
                icon: Icons.picture_as_pdf,
                tooltip: '另存为PDF（长图）',
                onPressed: _captureFullPage,
              ),
              const SizedBox(width: 4),
              _buildIconButton(
                icon: Icons.print,
                tooltip: '打印',
                onPressed: _print,
              ),
            ],
          ),
        );
      },
    );
  }

  // 统一样式的图标按钮
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!appState.isValidUrl) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.language, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  '🚀 Deskify',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '把任意网站变成桌面应用',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                const Text(
                  '在上方输入HTTPS网址开始使用',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (!_isWebViewInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        // 只在URL改变时加载
        if (appState.isValidUrl && _currentLoadedUrl != appState.currentUrl) {
          _currentLoadedUrl = appState.currentUrl;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _webViewController.loadUrl(appState.currentUrl);
          });
        }

        return Webview(_webViewController);
      },
    );
  }
}
