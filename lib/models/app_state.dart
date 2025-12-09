import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  String _currentUrl = 'https://';
  bool _isLoading = false;
  String? _errorMessage;

  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 是否是有效的HTTPS URL
  bool get isValidUrl {
    return _currentUrl.startsWith('https://') && _currentUrl.length > 8;
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

  // 加载保存的URL
  Future<void> loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('last_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载URL失败: $e');
    }
  }

  // 保存URL
  Future<void> saveUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_url', url);
      _currentUrl = url;
      notifyListeners();
    } catch (e) {
      debugPrint('保存URL失败: $e');
    }
  }
}
