import 'package:intl/intl.dart';

/// 셔틀 공지 리스트용 요약 모델
class ShuttleNoticeSummary {
  final String id;
  final String title;
  final DateTime postedAt;

  ShuttleNoticeSummary({
    required this.id,
    required this.title,
    required this.postedAt,
  });

  factory ShuttleNoticeSummary.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['_id'] as String? ?? json['id'] as String?;
      if (id == null) {
        throw FormatException('공지 ID가 없습니다. JSON: $json');
      }

      final title = json['title'] as String?;
      if (title == null || title.isEmpty) {
        throw FormatException('공지 제목이 없습니다. JSON: $json');
      }

      final postedAtStr = json['postedAt'] as String?;
      if (postedAtStr == null) {
        throw FormatException('공지 게시일이 없습니다. JSON: $json');
      }

      return ShuttleNoticeSummary(
        id: id,
        title: title,
        postedAt: DateTime.parse(postedAtStr),
      );
    } catch (e) {
      throw FormatException('ShuttleNoticeSummary 파싱 실패: $e, JSON: $json');
    }
  }

  /// UI에서 쓸 날짜 포맷 (예: 2025-11-22)
  String get formattedDate {
    return DateFormat('yyyy-MM-dd').format(postedAt.toLocal());
  }
}

/// 셔틀 공지 상세용 모델
class ShuttleNoticeDetail {
  final String id;
  final String title;
  final String content; // 원문 전체
  final String summary; // LLM 요약 (없으면 빈 문자열일 수 있음)
  final String url;     // 포털 원문 URL
  final DateTime postedAt;

  ShuttleNoticeDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.url,
    required this.postedAt,
  });

  factory ShuttleNoticeDetail.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['_id'] as String? ?? json['id'] as String?;
      if (id == null) {
        throw FormatException('공지 ID가 없습니다. JSON: $json');
      }

      final title = json['title'] as String?;
      if (title == null || title.isEmpty) {
        throw FormatException('공지 제목이 없습니다. JSON: $json');
      }

      final content = json['content'] as String?;
      if (content == null) {
        throw FormatException('공지 내용이 없습니다. JSON: $json');
      }

      // summary는 null이거나 빈 문자열일 수 있음 (LLM 요약이 없으면 서버에서 생성 중일 수 있음)
      final summary = (json['summary'] ?? '') as String? ?? '';

      final url = json['url'] as String?;
      if (url == null || url.isEmpty) {
        throw FormatException('공지 URL이 없습니다. JSON: $json');
      }

      final postedAtStr = json['postedAt'] as String?;
      if (postedAtStr == null) {
        throw FormatException('공지 게시일이 없습니다. JSON: $json');
      }

      return ShuttleNoticeDetail(
        id: id,
        title: title,
        content: content,
        summary: summary,
        url: url,
        postedAt: DateTime.parse(postedAtStr),
      );
    } catch (e) {
      throw FormatException('ShuttleNoticeDetail 파싱 실패: $e, JSON: $json');
    }
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd HH:mm').format(postedAt.toLocal());
  }

  bool get hasSummary => summary.trim().isNotEmpty;
}

