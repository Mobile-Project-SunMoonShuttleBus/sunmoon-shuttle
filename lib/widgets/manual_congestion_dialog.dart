import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../api/congestion_api.dart';
import '../models/congestion_models.dart';
import '../core/utils/global_keys.dart';

/// 수동 혼잡도 입력 다이얼로그 (탑승했다/못했다)
class ManualCongestionDialog extends StatefulWidget {
  final String busType; // 'shuttle' 또는 'campus'
  final String startId; // 출발지 이름
  final String stopId; // 도착지 이름
  final String departureTime; // 출발 시간 (HH:MM 형식)

  const ManualCongestionDialog({
    super.key,
    required this.busType,
    required this.startId,
    required this.stopId,
    required this.departureTime,
  });

  /// 전역 모달 표시 (어디 화면에 있든 표시)
  static void showGlobal({
    required String busType,
    required String startId,
    required String stopId,
    required String departureTime,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) {
        print('⚠️ navigatorKey.currentContext가 null입니다. 모달을 표시할 수 없습니다.');
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ManualCongestionDialog(
        busType: busType,
        startId: startId,
        stopId: stopId,
        departureTime: departureTime,
      ),
    );
  }

  @override
  State<ManualCongestionDialog> createState() => _ManualCongestionDialogState();
}

class _ManualCongestionDialogState extends State<ManualCongestionDialog> {
  bool? _selectedOption; // true: 탑승했다, false: 못했다
  bool _isSubmitting = false;
  Timer? _autoCloseTimer;
  int _remainingSeconds = 20;

  @override
  void initState() {
    super.initState();
    // 20초 타이머 시작
    _startAutoCloseTimer();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('혼잡도 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.startId} → ${widget.stopId}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            '출발 시간: ${widget.departureTime.startsWith('TEST') ? widget.departureTime.substring(4) : widget.departureTime}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            '버스를 탑승하셨나요?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOptionButton(true, '탑승했다', Colors.green, Icons.check_circle),
              const SizedBox(width: 12),
              _buildOptionButton(false, '못했다', Colors.red, Icons.cancel),
            ],
          ),
          const SizedBox(height: 16),
          // 자동 닫기 카운트다운
          Center(
            child: Text(
              '${_remainingSeconds}초 후 자동으로 닫힙니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () {
            _autoCloseTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedOption == null ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildOptionButton(bool option, String label, Color color, IconData icon) {
    final isSelected = _selectedOption == option;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOption = option;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 3 : 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected ? color : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedOption == null) return;

    _autoCloseTimer?.cancel();

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 탑승 여부에 따라 혼잡도 index 결정
      // 탑승했다 → 혼잡도 낮음 (index: 20)
      // 못했다 → 혼잡도 높음 (index: 85)
      final index = _selectedOption! ? 20 : 85;

      // 출발 시간을 파싱하여 timeSlot 계산
      // 테스트 모드 표시 제거 (TEST 접두사)
      final departureTimeStr = widget.departureTime.startsWith('TEST') 
          ? widget.departureTime.substring(4) 
          : widget.departureTime;
      
      final timeParts = departureTimeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final timeSlot = hour * 6 + (minute ~/ 10); // 10분 단위

      final now = DateTime.now();
      // 테스트 모드에서는 평일(월요일)을 사용하여 스케줄이 있는지 확인
      // 실제 모니터링에서는 현재 요일 사용
      // Dart의 weekday: 1=월요일, 7=일요일
      // 서버의 weekday: 0=일요일, 1=월요일, ..., 6=토요일 (서버 응답 확인)
      final isTestMode = widget.departureTime.startsWith('TEST');
      final weekday = isTestMode 
          ? 1  // 테스트 모드: 월요일 (서버 형식: 1=월요일)
          : (now.weekday == 7 ? 0 : now.weekday); // 실제 모니터링: 현재 요일 변환 (일요일=0, 월요일=1, ...)
      
      if (kDebugMode && isTestMode) {
        print('🧪 테스트 모드 감지: departureTime=${widget.departureTime}, weekday=$weekday (월요일)');
      }
      
      if (kDebugMode) {
        print('📅 요일 변환: Dart weekday=${now.weekday} → 서버 weekday=$weekday');
      }

      final request = CongestionReportRequest(
        busType: widget.busType,
        startId: widget.startId,
        stopId: widget.stopId,
        weekday: weekday,
        timeSlot: timeSlot,
        index: index,
        clientTs: now,
      );

      await CongestionApi.I.reportCongestion(request);

      if (mounted) {
        Navigator.of(context).pop(true); // 성공
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('혼잡도가 저장되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 혼잡도 저장 실패: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

