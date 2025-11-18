/// 캐시 매니저 (싱글톤)
/// SharedPreferences 기반 Key-Value 캐시 관리
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import 'cache_item.dart';

class CacheManager {
  CacheManager._internal();
  static final CacheManager I = CacheManager._internal();

  static const String _keyPrefix = 'cache_';
  static const int _maxCacheSizeBytes = 10 * 1024 * 1024; // 10MB

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// 초기화
  Future<void> init() async {
    if (_isInitialized && _prefs != null) {
      return; // 이미 초기화됨
    }
    
    _prefs ??= await SharedPreferences.getInstance();
    _isInitialized = true;
    
    // 앱 시작 시 만료된 캐시 정리
    await _cleanExpiredCache();
    // 캐시 크기 확인 및 정리
    await _cleanOldCacheIfNeeded();
  }

  /// 캐시 저장
  Future<void> setCache(String key, dynamic data, Duration ttl) async {
    if (!_isInitialized) {
      await init();
    }
    
    final cacheItem = CacheItem(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl,
    );

    try {
      final jsonString = jsonEncode(cacheItem.toJson());
      final cacheKey = _getCacheKey(key);
      
      await _prefs!.setString(cacheKey, jsonString);
      
      AppLogger.debug('CacheManager', '캐시 저장: $key (TTL: ${ttl.inSeconds}초)');
    } catch (e) {
      AppLogger.error('CacheManager', '캐시 저장 실패: $key', e is Error ? e.stackTrace : null);
    }
  }

  /// 캐시 조회
  Future<dynamic> getCache(String key) async {
    if (!_isInitialized) {
      await init();
    }
    
    final cacheKey = _getCacheKey(key);
    final jsonString = _prefs!.getString(cacheKey);
    
    if (jsonString == null) {
      return null;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final cacheItem = CacheItem.fromJson(json);
      
      // 만료 확인
      if (cacheItem.isExpired) {
        AppLogger.debug('CacheManager', '캐시 만료: $key');
        await _prefs!.remove(cacheKey);
        return null;
      }
      
      AppLogger.debug('CacheManager', '캐시 조회 성공: $key');
      return cacheItem.data;
    } catch (e) {
      AppLogger.error('CacheManager', '캐시 조회 실패: $key', e is Error ? e.stackTrace : null);
      // 잘못된 캐시 데이터 삭제
      await _prefs!.remove(cacheKey);
      return null;
    }
  }

  /// 캐시 삭제
  Future<void> removeCache(String key) async {
    if (!_isInitialized) {
      await init();
    }
    
    final cacheKey = _getCacheKey(key);
    await _prefs!.remove(cacheKey);
    AppLogger.debug('CacheManager', '캐시 삭제: $key');
  }

  /// 모든 캐시 삭제
  Future<void> clearAllCache() async {
    if (!_isInitialized) {
      await init();
    }
    
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
    AppLogger.info('CacheManager', '모든 캐시 삭제 완료');
  }

  /// 만료된 캐시 정리
  Future<void> _cleanExpiredCache() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_keyPrefix));
    int removedCount = 0;
    
    for (final key in keys) {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) continue;
      
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final cacheItem = CacheItem.fromJson(json);
        
        if (cacheItem.isExpired) {
          await _prefs!.remove(key);
          removedCount++;
        }
      } catch (e) {
        // 잘못된 캐시 데이터 삭제
        await _prefs!.remove(key);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      AppLogger.info('CacheManager', '만료된 캐시 $removedCount개 정리 완료');
    }
  }

  /// 캐시 크기 확인 및 오래된 캐시 정리
  Future<void> _cleanOldCacheIfNeeded() async {
    if (_prefs == null) return;
    
    final keys = _prefs!.getKeys().where((key) => key.startsWith(_keyPrefix));
    final cacheItems = <MapEntry<String, CacheItem>>[];
    
    // 모든 캐시 아이템 수집
    for (final key in keys) {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) continue;
      
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final cacheItem = CacheItem.fromJson(json);
        cacheItems.add(MapEntry(key, cacheItem));
      } catch (e) {
        // 잘못된 캐시 데이터 삭제
        await _prefs!.remove(key);
      }
    }
    
    // 전체 캐시 크기 계산
    int totalSize = 0;
    for (final entry in cacheItems) {
      final jsonString = jsonEncode(entry.value.toJson());
      totalSize += utf8.encode(jsonString).length;
    }
    
    // 10MB 초과 시 가장 오래된 캐시부터 제거
    if (totalSize > _maxCacheSizeBytes) {
      // cachedAt 기준으로 정렬 (오래된 것부터)
      cacheItems.sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
      
      int removedCount = 0;
      for (final entry in cacheItems) {
        if (totalSize <= _maxCacheSizeBytes) break;
        
        final jsonString = jsonEncode(entry.value.toJson());
        totalSize -= utf8.encode(jsonString).length;
        await _prefs!.remove(entry.key);
        removedCount++;
      }
      
      AppLogger.info('CacheManager', '캐시 크기 초과로 $removedCount개 캐시 정리 완료');
    }
  }

  /// 캐시 키 생성
  String _getCacheKey(String key) {
    return '$_keyPrefix$key';
  }

  /// 캐시 키 목록 조회 (디버그용)
  Future<List<String>> getCacheKeys() async {
    await init();
    
    final keys = _prefs!.getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .map((key) => key.substring(_keyPrefix.length))
        .toList();
    
    return keys;
  }
}

/// 캐시 키 상수
class CacheKeys {
  static const String favorites = 'favorites_cache.json';
  static const String crowdSnapshots = 'crowd_snapshots_cache.json';
  static const String timetable = 'timetable_cache.json';
  static const String notices = 'notices_cache.json';
}

/// 캐시 TTL 상수
class CacheTTL {
  static const Duration favorites = Duration(days: 1); // 1일
  static const Duration crowdSnapshots = Duration(seconds: 60); // 60초
  static const Duration timetable = Duration(minutes: 10); // 10분
  static const Duration notices = Duration(hours: 1); // 1시간
}

