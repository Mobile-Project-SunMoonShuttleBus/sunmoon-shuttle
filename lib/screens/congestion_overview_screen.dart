import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../api/congestion_api.dart';
import '../models/congestion_models.dart';

/// 혼잡도 Overview 화면
/// 셔틀버스/통학버스 탭 전환 및 노선별 혼잡도 카드 표시
class CongestionOverviewScreen extends StatefulWidget {
  const CongestionOverviewScreen({super.key});

  @override
  State<CongestionOverviewScreen> createState() => _CongestionOverviewScreenState();
}

class _CongestionOverviewScreenState extends State<CongestionOverviewScreen> {
  String _activeBusType = 'campus'; // 기본값: 통학버스
  String? _dayKey; // null이면 오늘 날짜
  bool _isLoading = false;
  String? _error;
  CongestionOverviewResponse? _data;

  @override
  void initState() {
    super.initState();
    _fetchOverview(_activeBusType);
  }

  /// Overview API 호출
  Future<void> _fetchOverview(String busType) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeBusType = busType;
    });

    try {
      final response = await CongestionApi.I.getOverview(
        busType: busType,
        dayKey: _dayKey,
      );

      setState(() {
        _data = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// lastUpdated를 HH:MM:SS 형식으로 포맷
  String _formatLastUpdated(String? lastUpdated) {
    if (lastUpdated == null) return '--:--:--';
    try {
      final dateTime = DateTime.parse(lastUpdated);
      return '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}:'
          '${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--:--';
    }
  }

  /// 혼잡도 레벨에 따른 색상 반환
  Color _getCongestionColor(String level) {
    switch (level) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 혼잡도 레벨에 따른 배경색 반환
  Color _getCongestionBackgroundColor(String level) {
    switch (level) {
      case 'LOW':
        return Colors.green.shade50;
      case 'MEDIUM':
        return Colors.orange.shade50;
      case 'HIGH':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 헤더 영역
          _buildHeader(),
          // 탭 영역
          _buildTabs(),
          // 본문 영역
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  /// 헤더 위젯
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 왼쪽: 제목
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '실시간 혼잡도 모니터링',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '실시간 업데이트 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 오른쪽: 마지막 업데이트 시간
          if (_data != null && _data!.lastUpdated != null)
            Text(
              '마지막 업데이트: ${_formatLastUpdated(_data!.lastUpdated)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  /// 탭 위젯
  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('셔틀버스', 'shuttle'),
          ),
          Expanded(
            child: _buildTabButton('통학버스', 'campus'),
          ),
        ],
      ),
    );
  }

  /// 탭 버튼 위젯
  Widget _buildTabButton(String label, String busType) {
    final isActive = _activeBusType == busType;
    return GestureDetector(
      onTap: () => _fetchOverview(busType),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  /// 본문 위젯
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '데이터를 불러오는 중...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchOverview(_activeBusType),
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    if (_data == null || _data!.routes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '현재 혼잡도 데이터가 없습니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchOverview(_activeBusType),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _data!.routes.length,
        itemBuilder: (context, index) {
          return _buildRouteSection(_data!.routes[index]);
        },
      ),
    );
  }

  /// 노선 섹션 위젯
  Widget _buildRouteSection(CongestionRoute route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 노선 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    route.routeTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  '${route.timeSlotsCount}개 시간대',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // 카드 그리드
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: route.cards.map((card) => _buildCard(card)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 혼잡도 카드 위젯
  Widget _buildCard(CongestionCard card) {
    final color = _getCongestionColor(card.congestionLevel);
    final backgroundColor = _getCongestionBackgroundColor(card.congestionLevel);

    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 출발 시간
          Text(
            card.departureTime,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          // 혼잡도 라벨
          Text(
            card.congestionLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          // 샘플 수
          Text(
            '샘플 ${card.samples}건',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

