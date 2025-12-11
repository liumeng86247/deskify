import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

/// 欢迎页 - 当没有URL时显示
class WelcomePage extends StatefulWidget {
  final String? cachedUrl; // 缓存的网址
  final Function(String)? onLoadUrl; // 加载网址的回调
  
  const WelcomePage({
    super.key,
    this.cachedUrl,
    this.onLoadUrl,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late TextEditingController _urlController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.cachedUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// 判断URL是否被修改
  bool get _isUrlModified {
    final currentUrl = _urlController.text.trim();
    final cachedUrl = widget.cachedUrl?.trim() ?? '';
    return currentUrl != cachedUrl && currentUrl.isNotEmpty;
  }

  void _handleLoadUrl() {
    final t = context.read<AppState>().tr;
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      setState(() {
        _errorMessage = t(zh: '请输入网址', en: 'Please enter a URL');
      });
      return;
    }
    
    if (!url.startsWith('https://')) {
      setState(() {
        _errorMessage = t(zh: '⚠️ 仅支持 HTTPS 网站', en: '⚠️ HTTPS sites only');
      });
      return;
    }
    
    setState(() {
      _errorMessage = null;
    });
    
    widget.onLoadUrl?.call(url);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.tr;
    // 获取屏幕宽度
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 900; // 小屏幕阈值
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 40,
            vertical: isSmallScreen ? 12 : 30,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.desktop_windows_rounded,
                  size: isSmallScreen ? 40 : 56,
                  color: Colors.blue,
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 28),
              
              // 标题
              Text(
                t(zh: '欢迎使用 Deskify', en: 'Welcome to Deskify'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 6 : 10),
              
              // 副标题
              Text(
                t(zh: '将任意网站封装为桌面应用', en: 'Turn any website into a desktop app'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 15,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 32),
              
              // 地址栏输入区域（可编辑的上次访问网址）
              if (widget.cachedUrl != null && widget.cachedUrl!.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? double.infinity : 700,
                  ),
                  child: Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 14 : 24),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 20,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 单行布局：标题 + 地址栏 + 按钮
                      Row(
                        children: [
                          // 标题图标
                          Icon(
                            Icons.history,
                            color: Colors.blue,
                            size: isSmallScreen ? 18 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t(zh: '上次访问', en: 'Last visit'),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // 地址栏（占据剩余空间）
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                hintText: t(zh: '输入 HTTPS 网址', en: 'Enter HTTPS URL'),
                                hintStyle: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 13,
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: Icon(Icons.link, color: Colors.blue, size: isSmallScreen ? 16 : 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _urlController.clear();
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  },
                                  tooltip: t(zh: '清空', en: 'Clear'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: isSmallScreen ? 8 : 10,
                                ),
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                fontFamily: 'monospace',
                              ),
                              onSubmitted: (_) => _handleLoadUrl(),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // 按钮
                          ElevatedButton.icon(
                            onPressed: _handleLoadUrl,
                            icon: Icon(
                              _isUrlModified ? Icons.open_in_new : Icons.refresh,
                              size: isSmallScreen ? 14 : 16,
                            ),
                            label: Text(
                              _isUrlModified
                                  ? t(zh: '访问', en: 'Open')
                                  : t(zh: '继续', en: 'Continue'),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 1,
                            ),
                          ),
                        ],
                      ),
                      
                      // 错误提示
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              else
                // 没有缓存网址时显示简单输入框
                Container(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? double.infinity : 600,
                  ),
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 14 : 24),
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.web,
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.blue,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        t(zh: '输入 HTTPS 网址开始使用', en: 'Enter an HTTPS URL to start'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        t(
                          zh: '请在顶部标题栏的地址栏中输入网址',
                          en: 'Please type the URL in the top title bar input',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 功能介绍卡片
              _buildFeatureCards(isSmallScreen, t),
              
              SizedBox(height: isSmallScreen ? 16 : 32),
              
              // 使用提示
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: isSmallScreen ? 20 : 26,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      t(zh: '快速开始', en: 'Quick start'),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      t(
                        zh: '在顶部地址栏输入 HTTPS 网址，即可开始使用',
                        en: 'Enter an HTTPS URL in the top bar to start',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 14 : 24),
              
              // 版权信息
              Text(
                t(
                  zh: '© 2025 Deskify - 定制桌面应用解决方案',
                  en: '© 2025 Deskify - Custom desktop app solutions',
                ),
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureCards(
    bool isSmallScreen,
    String Function({required String zh, required String en}) t,
  ) {
    return Wrap(
      spacing: isSmallScreen ? 8 : 14,
      runSpacing: isSmallScreen ? 8 : 14,
      alignment: WrapAlignment.center,
      children: [
        _buildFeatureCard(
          icon: Icons.language,
          title: t(zh: '跨平台支持', en: 'Cross-platform'),
          description: 'Windows / macOS / Linux',
          color: Colors.blue,
          isSmallScreen: isSmallScreen,
        ),
        _buildFeatureCard(
          icon: Icons.security,
          title: t(zh: 'HTTPS 安全', en: 'HTTPS only'),
          description: t(zh: '仅支持安全的HTTPS网站', en: 'Only secure HTTPS sites'),
          color: Colors.green,
          isSmallScreen: isSmallScreen,
        ),
        _buildFeatureCard(
          icon: Icons.memory,
          title: t(zh: '记忆功能', en: 'Memory'),
          description: t(zh: '自动记住上次访问的网址', en: 'Remembers the last URL'),
          color: Colors.purple,
          isSmallScreen: isSmallScreen,
        ),
        _buildFeatureCard(
          icon: Icons.settings_overscan,
          title: t(zh: '自适应缩放', en: 'Auto zoom'),
          description: t(zh: '窗口大小自动适配', en: 'Adapts to window size'),
          color: Colors.orange,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }
  
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      width: isSmallScreen ? 150 : 170,
      padding: EdgeInsets.all(isSmallScreen ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: isSmallScreen ? 24 : 32, color: color),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
