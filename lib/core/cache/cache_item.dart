/// 캐시 아이템 모델
/// 데이터와 TTL 정보를 포함
class CacheItem {
  final dynamic data;
  final DateTime cachedAt;
  final Duration ttl; // Time To Live

  CacheItem({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  /// 캐시가 만료되었는지 확인
  bool get isExpired {
    final now = DateTime.now();
    final expiresAt = cachedAt.add(ttl);
    return now.isAfter(expiresAt);
  }

  /// 만료까지 남은 시간
  Duration get timeUntilExpiry {
    final now = DateTime.now();
    final expiresAt = cachedAt.add(ttl);
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'cachedAt': cachedAt.toIso8601String(),
      'ttlSeconds': ttl.inSeconds,
    };
  }

  /// JSON에서 생성
  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      data: json['data'],
      cachedAt: DateTime.parse(json['cachedAt']),
      ttl: Duration(seconds: json['ttlSeconds'] as int),
    );
  }
}

