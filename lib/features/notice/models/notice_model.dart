import 'package:flutter/material.dart';

/// 공지사항 모델
/// 셔틀 관련 공지사항 데이터 구조
class NoticeModel {
  final String id;
  final String title;
  final String level; // CANCEL, DELAY 등
  final DateTime startAt;
  final DateTime endAt;
  final String? body; // 본문 (상세 조회 시에만 포함)
  final String? scope; // ROUTE 등
  final String? routeId; // R001 등

  NoticeModel({
    required this.id,
    required this.title,
    required this.level,
    required this.startAt,
    required this.endAt,
    this.body,
    this.scope,
    this.routeId,
  });

  /// JSON에서 NoticeModel 생성 (목록용)
  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['_id'] as String,
      title: json['title'] as String,
      level: json['level'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      body: json['body'] as String?,
      scope: json['scope'] as String?,
      routeId: json['route_id'] as String?,
    );
  }

  /// 현재 진행 중인 공지인지 확인
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startAt) && now.isBefore(endAt);
  }

  /// 공지 레벨에 따른 색상 반환
  Color get levelColor {
    switch (level.toUpperCase()) {
      case 'CANCEL':
        return Colors.red;
      case 'DELAY':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// 공지 레벨에 따른 텍스트 반환
  String get levelText {
    switch (level.toUpperCase()) {
      case 'CANCEL':
        return '운행 중단';
      case 'DELAY':
        return '운행 지연';
      default:
        return '공지';
    }
  }
}

/// 공지사항 응답 모델
class NoticeResponseModel {
  final List<NoticeModel> data;
  final String? etag;

  NoticeResponseModel({
    required this.data,
    this.etag,
  });

  factory NoticeResponseModel.fromJson(Map<String, dynamic> json) {
    return NoticeResponseModel(
      data: (json['data'] as List<dynamic>)
          .map((item) => NoticeModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      etag: json['meta']?['etag'] as String?,
    );
  }
}

