/// 시간표 모델 클래스
/// API 응답 데이터 구조화
class TimetableResponse {
  final bool success;
  final int count;
  final String crawlingStatus;
  final String statusMessage;
  final DateTime? lastCrawledAt;
  final Map<String, List<TimetableSubject>> timetable;

  TimetableResponse({
    required this.success,
    required this.count,
    required this.crawlingStatus,
    required this.statusMessage,
    this.lastCrawledAt,
    required this.timetable,
  });

  factory TimetableResponse.fromMap(Map<String, dynamic> map) {
    final timetableMap = <String, List<TimetableSubject>>{};
    
    if (map['timetable'] is Map) {
      final timetableData = map['timetable'] as Map<String, dynamic>;
      timetableData.forEach((day, subjects) {
        if (subjects is List) {
          timetableMap[day] = subjects
              .map((subject) => TimetableSubject.fromMap(subject as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return TimetableResponse(
      success: map['success'] ?? false,
      count: map['count'] ?? 0,
      crawlingStatus: map['crawlingStatus']?.toString() ?? 'unknown',
      statusMessage: map['statusMessage']?.toString() ?? '',
      lastCrawledAt: map['lastCrawledAt'] != null
          ? DateTime.tryParse(map['lastCrawledAt'].toString())
          : null,
      timetable: timetableMap,
    );
  }
}

/// 시간표 과목 모델
class TimetableSubject {
  final String subjectName;
  final String startTime;
  final String endTime;
  final String location;
  final String professor;

  TimetableSubject({
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.professor,
  });

  factory TimetableSubject.fromMap(Map<String, dynamic> map) {
    return TimetableSubject(
      subjectName: map['subjectName']?.toString() ?? '',
      startTime: map['startTime']?.toString() ?? '',
      endTime: map['endTime']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      professor: map['professor']?.toString() ?? '',
    );
  }

  /// 시간 문자열을 DateTime으로 변환 (오늘 날짜 기준)
  DateTime get startDateTime {
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime get endDateTime {
    final parts = endTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 10;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// 시간대 인덱스 (9시 = 0, 10시 = 1, ...)
  int get startTimeIndex {
    final hour = startDateTime.hour;
    return hour - 9; // 9시부터 시작
  }

  int get endTimeIndex {
    final hour = endDateTime.hour;
    return hour - 9; // 9시부터 시작
  }

  /// 시간 차이 (시간 단위)
  double get durationInHours {
    return endDateTime.difference(startDateTime).inMinutes / 60.0;
  }
}