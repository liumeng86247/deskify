import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cache_service.dart';

class AppState extends ChangeNotifier {
  String _currentUrl = 'https://';
  bool _isLoading = false;
  String? _errorMessage;
  final CacheService _cacheService = CacheService();
  bool _isLoadingFromCache = false;

  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoadingFromCache => _isLoadingFromCache;

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

  // 加载保存的URL（带缓存加载和30秒超时）
  Future<void> loadSavedUrl() async {
    try {
      _isLoadingFromCache = true;
      notifyListeners();

      // 从SharedPreferences加载上次的URL
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('last_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
        debugPrint('📥 从SharedPreferences加载URL: $_currentUrl');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ 加载URL失败: $e');
    } finally {
      _isLoadingFromCache = false;
      notifyListeners();
    }
  }

  // 保存URL
  Future<void> saveUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_url', url);
      _currentUrl = url;
      
      // 检查是否已有该URL的成功缓存
      final existingCache = await _cacheService.loadCacheData(url, useTimeout: false);
      
      // 只有在没有成功缓存时，才创建初始缓存
      if (existingCache == null || !existingCache.isLoadSuccess) {
        await _saveCacheData(url, isSuccess: false);
        debugPrint('📝 为新URL创建初始缓存 [$url]');
      } else {
        debugPrint('✅ URL已有成功缓存，不创建新缓存 [$url]');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 保存URL失败: $e');
    }
  }

  // 保存缓存数据（按URL）
  Future<void> _saveCacheData(String url, {bool isSuccess = false, String? pageTitle}) async {
    try {
      // 先读取现有缓存，保留上次成功时间
      final existingCache = await _cacheService.loadCacheData(url, useTimeout: false);
      
      final cacheData = CacheData(
        url: url,
        timestamp: DateTime.now(),
        lastSuccessTime: isSuccess ? DateTime.now() : existingCache?.lastSuccessTime,
        isLoadSuccess: isSuccess,
        pageTitle: pageTitle,
        metadata: {
          'version': '1.0.0',
          'platform': 'windows',
        },
      );
      await _cacheService.saveCacheData(url, cacheData);
    } catch (e) {
      debugPrint('❌ 保存缓存数据失败: $e');
    }
  }

  // 更新缓存为成功状态（WebView加载成功后调用）
  Future<void> updateCacheAsSuccess(String url, {String? pageTitle}) async {
    await _saveCacheData(url, isSuccess: true, pageTitle: pageTitle);
    debugPrint('✅ 缓存已更新为成功状态 [$url]');
  }

  // 获取指定URL的缓存数据
  Future<CacheData?> getCacheForUrl(String url) async {
    return await _cacheService.loadCacheData(url, useTimeout: false);
  }

  // 清除所有缓存
  Future<void> clearAllCache() async {
    try {
      await _cacheService.clearAllCache();
      debugPrint('✅ 所有缓存已清除');
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
    }
  }

  // 清除指定URL的缓存
  Future<void> clearCacheForUrl(String url) async {
    try {
      await _cacheService.clearCacheForUrl(url);
      debugPrint('✅ URL缓存已清除 [$url]');
    } catch (e) {
      debugPrint('❌ 清除URL缓存失败: $e');
    }
  }

  // 获取所有缓存信息（用于调试）
  Future<String> getAllCacheInfo() async {
    return await _cacheService.getAllCacheInfo();
  }

  // 获取当前URL的缓存信息
  Future<String> getCacheInfo() async {
    return await _cacheService.getCacheInfo(_currentUrl);
  }
}
