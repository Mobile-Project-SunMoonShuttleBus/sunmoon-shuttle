/// 혼잡도 관련 모델

/// 혼잡도 리포트 요청 모델
class CongestionReportRequest {
  final String busType; // shuttle 또는 campus
  final String startId; // 출발지 이름 (예: "아산캠퍼스")
  final String stopId; // 도착지 이름 (예: "아산(KTX)역")
  final int weekday; // 0=월요일, 6=일요일
  final int timeSlot; // 10분 단위: 08:00 = 8*6+0 = 48
  final int index; // 혼잡도 지수: 0~100
  final DateTime? clientTs; // 단말에서 리포트 전송 시각 (선택)
  final CongestionMeta? meta; // 메타 정보 (선택)

  CongestionReportRequest({
    required this.busType,
    required this.startId,
    required this.stopId,
    required this.weekday,
    required this.timeSlot,
    required this.index,
    this.clientTs,
    this.meta,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'busType': busType,
      'startId': startId,
      'stopId': stopId,
      'weekday': weekday,
      'timeSlot': timeSlot,
      'index': index,
    };
    
    if (clientTs != null) {
      json['clientTs'] = clientTs!.toIso8601String();
    }
    
    if (meta != null) {
      json['meta'] = meta!.toJson();
    }
    
    return json;
  }
}

/// 혼잡도 리포트 메타 정보
class CongestionMeta {
  final String? appVer; // 앱 버전
  final String? os; // 단말 OS (android/ios)
  final double? gpsAcc; // GPS 정확도 (미터 단위)

  CongestionMeta({
    this.appVer,
    this.os,
    this.gpsAcc,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (appVer != null) json['app_ver'] = appVer;
    if (os != null) json['os'] = os;
    if (gpsAcc != null) json['gps_acc'] = gpsAcc;
    return json;
  }
}

/// 혼잡도 리포트 응답 모델
class CongestionReportResponse {
  final bool success;
  final String message;
  final String? logId;

  CongestionReportResponse({
    required this.success,
    required this.message,
    this.logId,
  });

  factory CongestionReportResponse.fromJson(Map<String, dynamic> json) {
    return CongestionReportResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      logId: json['data']?['logId'],
    );
  }
}

/// 위치 정보 모델
class LocationData {
  final double latitude;
  final double longitude;
  final double? speed; // m/s
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.speed,
    required this.timestamp,
  });
}

/// 속도 측정 결과
class SpeedMeasurement {
  final double speedKmh; // km/h
  final double distance; // m
  final Duration duration; // 초

  SpeedMeasurement({
    required this.speedKmh,
    required this.distance,
    required this.duration,
  });
}

