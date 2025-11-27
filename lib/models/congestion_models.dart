/// 혼잡도 관련 모델

/// 혼잡도 리포트 요청 모델
class CongestionReportRequest {
  final String routeId;
  final String stopId;
  final int weekday; // 0=월요일, 6=일요일
  final int timeSlot; // 10분 단위: 08:00 = 8*6+0 = 48
  final int index; // 혼잡도 지수: 0~100

  CongestionReportRequest({
    required this.routeId,
    required this.stopId,
    required this.weekday,
    required this.timeSlot,
    required this.index,
  });

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'stopId': stopId,
      'weekday': weekday,
      'timeSlot': timeSlot,
      'index': index,
    };
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

