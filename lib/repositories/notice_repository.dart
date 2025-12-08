/// 공지사항 Repository
/// API 호출을 추상화하고 예외 처리
import 'package:dio/dio.dart';
import './../api/notice_api.dart';
import '../models/notice_model.dart';

class NoticeRepository {
  NoticeRepository._internal();
  static final NoticeRepository I = NoticeRepository._internal();

  /// 공지사항 목록 조회
  /// 성공 시 NoticeResponseModel 반환, 실패 시 예외 발생
  Future<NoticeResponseModel> getNotices({
    String? routeId,
  }) async {
    try {
      final res = await NoticeApi.I.getNotices(routeId: routeId);
      return NoticeResponseModel.fromJson(res);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        final message = errorData['message']?.toString() ?? '공지사항 조회 실패';
        throw NoticeException(message: message);
      }
      throw NoticeException(message: '공지사항 조회 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is NoticeException) rethrow;
      throw NoticeException(message: '공지사항 조회 중 오류가 발생했습니다.');
    }
  }

  /// 공지사항 상세 조회
  /// 성공 시 NoticeModel 반환, 실패 시 예외 발생
  Future<NoticeModel> getNoticeDetail({
    required String noticeId,
  }) async {
    try {
      final res = await NoticeApi.I.getNoticeDetail(noticeId: noticeId);
      final data = res['data'] as Map<String, dynamic>;
      return NoticeModel.fromJson(data);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData is Map) {
        final message = errorData['message']?.toString() ?? '공지사항 상세 조회 실패';
        throw NoticeException(message: message);
      }
      throw NoticeException(message: '공지사항 상세 조회 중 오류가 발생했습니다.');
    } catch (e) {
      if (e is NoticeException) rethrow;
      throw NoticeException(message: '공지사항 상세 조회 중 오류가 발생했습니다.');
    }
  }
}

class NoticeException implements Exception {
  final String message;
  NoticeException({required this.message});
  @override
  String toString() => message;
}

