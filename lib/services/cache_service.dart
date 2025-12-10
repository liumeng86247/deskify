import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用缓存数据模型
class CacheData {
  final String url;
  final DateTime timestamp;
  final DateTime? lastSuccessTime; // 上次成功加载时间
  final bool isLoadSuccess; // 是否加载成功
  final String? pageTitle; // 页面标题（如果可获取）
  final Map<String, dynamic> metadata;

  CacheData({
    required this.url,
    required this.timestamp,
    this.lastSuccessTime,
    this.isLoadSuccess = false,
    this.pageTitle,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  // 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'timestamp': timestamp.toIso8601String(),
      'lastSuccessTime': lastSuccessTime?.toIso8601String(),
      'isLoadSuccess': isLoadSuccess,
      'pageTitle': pageTitle,
      'metadata': metadata,
    };
  }

  // 从JSON反序列化
  factory CacheData.fromJson(Map<String, dynamic> json) {
    return CacheData(
      url: json['url'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      lastSuccessTime: json['lastSuccessTime'] != null 
          ? DateTime.parse(json['lastSuccessTime'] as String)
          : null,
      isLoadSuccess: json['isLoadSuccess'] as bool? ?? false,
      pageTitle: json['pageTitle'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  // 判断缓存是否过期（超过30天）
  bool isExpired() {
    return DateTime.now().difference(timestamp).inDays > 30;
  }

  // 获取缓存时长（秒）
  int getCacheAge() {
    return DateTime.now().difference(timestamp).inSeconds;
  }
}

/// 缓存服务类 - 负责应用数据的持久化缓存（Key-Value模式）
class CacheService {
  static const String _cacheMapKey = 'app_cache_map'; // 存储所有缓存的Map
  static const Duration _loadTimeout = Duration(seconds: 30);
  
  /// 保存指定URL的缓存数据（Key-Value模式）
  Future<bool> saveCacheData(String url, CacheData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 读取现有的缓存Map
      final cacheMapString = prefs.getString(_cacheMapKey);
      Map<String, dynamic> cacheMap = {};
      
      if (cacheMapString != null && cacheMapString.isNotEmpty) {
        cacheMap = jsonDecode(cacheMapString) as Map<String, dynamic>;
      }
      
      // 更新该URL的缓存
      cacheMap[url] = data.toJson();
      
      // 保存回去
      final result = await prefs.setString(_cacheMapKey, jsonEncode(cacheMap));
      debugPrint('💾 缓存已保存 [$url]: ${data.isLoadSuccess ? "成功" : "待更新"}');
      return result;
    } catch (e) {
      debugPrint('❌ 保存缓存失败: $e');
      return false;
    }
  }

  /// 加载指定URL的缓存数据（带30秒超时机制）
  Future<CacheData?> loadCacheData(String url, {bool useTimeout = true}) async {
    try {
      if (useTimeout) {
        // 使用超时机制
        return await _loadWithTimeout(url);
      } else {
        // 直接加载
        return await _loadCache(url);
      }
    } catch (e) {
      debugPrint('❌ 加载缓存失败: $e');
      return null;
    }
  }

  /// 带超时的加载方法
  Future<CacheData?> _loadWithTimeout(String url) async {
    try {
      final result = await Future.any([
        _loadCache(url),
        Future.delayed(_loadTimeout, () => null),
      ]);

      if (result == null) {
        debugPrint('⏱️ 加载超时（30秒），未找到缓存数据 [$url]');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ 超时加载失败: $e');
      return null;
    }
  }

  /// 实际的加载逻辑（从Map中读取指定URL的缓存）
  Future<CacheData?> _loadCache(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheMapString = prefs.getString(_cacheMapKey);
    
    if (cacheMapString == null || cacheMapString.isEmpty) {
      debugPrint('ℹ️ 未找到缓存Map');
      return null;
    }

    try {
      final cacheMap = jsonDecode(cacheMapString) as Map<String, dynamic>;
      
      // 查找该URL的缓存
      if (!cacheMap.containsKey(url)) {
        debugPrint('ℹ️ 未找到该URL的缓存 [$url]');
        return null;
      }
      
      final json = cacheMap[url] as Map<String, dynamic>;
      final cacheData = CacheData.fromJson(json);
      
      // 检查缓存是否过期
      if (cacheData.isExpired()) {
        debugPrint('⚠️ 缓存已过期 [$url] (${cacheData.getCacheAge()}秒前)');
        await clearCacheForUrl(url);
        return null;
      }

      debugPrint('✅ 缓存加载成功 [$url]: ${cacheData.getCacheAge()}秒前');
      return cacheData;
    } catch (e) {
      debugPrint('❌ 解析缓存数据失败: $e');
      return null;
    }
  }

  /// 清除所有缓存
  Future<bool> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_cacheMapKey);
      debugPrint('🗑️ 所有缓存已清除');
      return result;
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
      return false;
    }
  }

  /// 清除指定URL的缓存
  Future<bool> clearCacheForUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMapString = prefs.getString(_cacheMapKey);
      
      if (cacheMapString == null || cacheMapString.isEmpty) {
        return true;
      }
      
      final cacheMap = jsonDecode(cacheMapString) as Map<String, dynamic>;
      cacheMap.remove(url);
      
      final result = await prefs.setString(_cacheMapKey, jsonEncode(cacheMap));
      debugPrint('🗑️ 已清除缓存 [$url]');
      return result;
    } catch (e) {
      debugPrint('❌ 清除URL缓存失败: $e');
      return false;
    }
  }

  /// 检查是否存在缓存
  Future<bool> hasCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cacheMapKey);
    } catch (e) {
      debugPrint('❌ 检查缓存失败: $e');
      return false;
    }
  }

  /// 检查指定URL是否有缓存
  Future<bool> hasCacheForUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMapString = prefs.getString(_cacheMapKey);
      
      if (cacheMapString == null || cacheMapString.isEmpty) {
        return false;
      }
      
      final cacheMap = jsonDecode(cacheMapString) as Map<String, dynamic>;
      return cacheMap.containsKey(url);
    } catch (e) {
      debugPrint('❌ 检查URL缓存失败: $e');
      return false;
    }
  }

  /// 获取所有缓存信息（用于调试）
  Future<String> getAllCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMapString = prefs.getString(_cacheMapKey);
      
      if (cacheMapString == null || cacheMapString.isEmpty) {
        return '无缓存数据';
      }
      
      final cacheMap = jsonDecode(cacheMapString) as Map<String, dynamic>;
      final buffer = StringBuffer();
      buffer.writeln('📦 缓存总数: ${cacheMap.length}\n');
      
      int index = 1;
      for (var entry in cacheMap.entries) {
        final url = entry.key;
        final cacheData = CacheData.fromJson(entry.value as Map<String, dynamic>);
        
        buffer.writeln('[$index] URL: $url');
        if (cacheData.pageTitle != null) {
          buffer.writeln('    标题: ${cacheData.pageTitle}');
        }
        buffer.writeln('    状态: ${cacheData.isLoadSuccess ? "✅ 成功" : "⚠️ 未成功"}');
        buffer.writeln('    年龄: ${cacheData.getCacheAge()}秒');
        if (cacheData.lastSuccessTime != null) {
          final successAge = DateTime.now().difference(cacheData.lastSuccessTime!).inSeconds;
          buffer.writeln('    上次成功: $successAge秒前');
        }
        buffer.writeln('');
        index++;
      }
      
      return buffer.toString();
    } catch (e) {
      return '获取缓存信息失败: $e';
    }
  }

  /// 获取指定URL的缓存信息
  Future<String> getCacheInfo(String url) async {
    try {
      final cache = await loadCacheData(url, useTimeout: false);
      if (cache == null) {
        return '该URL无缓存数据';
      }
      
      final buffer = StringBuffer();
      buffer.writeln('缓存URL: ${cache.url}');
      if (cache.pageTitle != null) {
        buffer.writeln('页面标题: ${cache.pageTitle}');
      }
      buffer.writeln('缓存时间: ${cache.timestamp}');
      buffer.writeln('缓存年龄: ${cache.getCacheAge()}秒');
      buffer.writeln('加载状态: ${cache.isLoadSuccess ? "✅ 成功" : "⚠️ 未成功"}');
      if (cache.lastSuccessTime != null) {
        final successAge = DateTime.now().difference(cache.lastSuccessTime!).inSeconds;
        buffer.writeln('上次成功: ${cache.lastSuccessTime} ($successAge秒前)');
      }
      buffer.writeln('是否过期: ${cache.isExpired() ? "是" : "否"}');
      
      return buffer.toString();
    } catch (e) {
      return '获取缓存信息失败: $e';
    }
  }
}
