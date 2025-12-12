import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  String _currentUrl = '';
  bool _isLoading = false;
  String? _errorMessage;
  String _pageTitle = 'Deskify'; // 页面标题
  String? _favIconUrl; // 网站图标URL
  bool _showWelcomePage = false; // 是否显示欢迎页
  bool _isEnglish = false; // 语言：false=中文，true=英文

  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get pageTitle => _pageTitle;
  String? get favIconUrl => _favIconUrl;
  bool get isEnglish => _isEnglish;

  // 是否是有效的HTTPS URL
  bool get isValidUrl {
    return _currentUrl.startsWith('https://') && _currentUrl.length > 8;
  }

  // 是否显示首页
  bool get shouldShowWelcome {
    return _showWelcomePage;
  }

  // 更新URL
  void updateUrl(String url) {
    _currentUrl = url;
    _errorMessage = null;
    notifyListeners();
  }

  // 设置加载状态
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 设置错误信息
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 文案翻译助手
  String tr({required String zh, required String en}) => _isEnglish ? en : zh;

  // 初始化：加载语言与URL
  Future<void> initialize() async {
    await Future.wait([
      _loadSavedLanguage(),
      loadSavedUrl(),
    ]);
  }

  // 加载保存的URL
  Future<void> loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('last_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
        _showWelcomePage = false; // 有URL时不显示欢迎页
        debugPrint('📥 加载上次访问的URL: $_currentUrl');
      } else {
        _currentUrl = ''; // 空URL显示欢迎页
        _showWelcomePage = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 加载URL失败: $e');
      _currentUrl = '';
      _showWelcomePage = true;
      notifyListeners();
    }
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('language');
      if (saved == 'en') {
        _isEnglish = true;
      } else {
        _isEnglish = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 加载语言设置失败: $e');
    }
  }

  Future<void> toggleLanguage() async {
    await setLanguage(!_isEnglish);
  }

  Future<void> setLanguage(bool isEnglish) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnglish = isEnglish;
      await prefs.setString('language', _isEnglish ? 'en' : 'zh');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 保存语言设置失败: $e');
    }
  }

  // 更新页面标题
  void updatePageTitle(String title) {
    _pageTitle = title.isEmpty ? 'Deskify' : title;
    notifyListeners();
  }

  // 更新网站图标
  void updateFavIcon(String? iconUrl) {
    _favIconUrl = iconUrl;
    notifyListeners();
  }

  // 重置页面信息
  void resetPageInfo() {
    _pageTitle = 'Deskify';
    _favIconUrl = null;
    notifyListeners();
  }

  // 显示欢迎页
  void showWelcome() {
    _showWelcomePage = true;
    resetPageInfo();
    notifyListeners();
  }

  // 隐藏欢迎页
  void hideWelcome() {
    _showWelcomePage = false;
    notifyListeners();
  }

  // 保存URL
  Future<void> saveUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_url', url);
      _currentUrl = url;
      _showWelcomePage = false; // 保存URL后隐藏欢迎页
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 保存URL失败: $e');
    }
  }

  // 清除URL缓存（用于打包前清除测试数据）
  Future<void> clearUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_url');
      _currentUrl = '';
      _showWelcomePage = true;
      debugPrint('✅ URL缓存已清除');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 清除URL缓存失败: $e');
    }
  }
}
