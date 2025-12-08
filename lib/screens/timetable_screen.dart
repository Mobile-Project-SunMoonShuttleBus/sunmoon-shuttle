// 백엔드 api 정상화시 적용할 코드
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart'; // Dio 패키지
import 'dart:math'; // max 함수 사용을 위해 필수
import '../api/dio_client.dart'; // DioClient 경로에 맞게 수정해주세요

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _selectedTabIndex = -1;

  // 1. 탭에 표시될 이름 (화면 표시용)
  final List<String> _tabNames = [
    '아산(KTX)역',
    '천안역',
    '천안 터미널',
    '온양 터미널/역'
  ];

  // 2. API 요청 시 사용할 정확한 도착지/출발지 명칭 (서버 요청용)
  final Map<int, String> _tabApiArrivalNames = {
    0: '천안 아산역',
    1: '천안역',
    2: '천안 터미널',
    3: '온양역/아산터미널'
  };

  // 3. 백엔드 데이터와 매칭할 다양한 이름들 (별칭 리스트)
  final Map<String, List<String>> _stationAliases = {
    '천안 아산역': ['천안아산역', '아산역', 'KTX'],
    '천안역': ['천안역', '서부역', '천안역(서부)', '천안역(동부)', '천안서부역'],
    '천안 터미널': ['천안터미널', '종합터미널', '천안종합터미널', '터미널', '야우리'],
    '온양역/아산터미널': ['온양온천역', '온양역', '온양터미널', '아산터미널', '온양역/아산터미널']
  };

  bool _isTimetableLoading = false;
  Map<String, dynamic>? _currentTimetableData;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabNames.isNotEmpty) {
        _loadTimetableFor(0);
      }
    });
  }

  void _loadTimetableFor(int index) {
    if (_selectedTabIndex == index && _currentTimetableData != null) return;

    final String targetName = _tabApiArrivalNames[index]!;

    setState(() {
      _selectedTabIndex = index;
      _isTimetableLoading = true;
      _currentTimetableData = null;
      _errorMessage = "";
    });

    _fetchTimetableData(targetName);
  }

  Future<void> _fetchTimetableData(String targetName) async {
    try {
      final results = await Future.wait([
        // 1. 하행 (캠퍼스 -> 역)
        DioClient.instance.get(
          '/api/shuttle/schedules',
          queryParameters: {
            'dayType': '평일',
            'departure': '아산캠퍼스',
            'arrival': targetName,
            'limit': '0'
          },
        ),
        // 2. 상행 (역 -> 캠퍼스)
        DioClient.instance.get(
          '/api/shuttle/schedules',
          queryParameters: {
            'dayType': '평일',
            'departure': targetName,
            'arrival': '아산캠퍼스',
            'limit': '0'
          },
        ),
      ]);

      if (!mounted) return;

      final downBoundData = results[0].data;
      final upBoundData = results[1].data;

      final processedData =
          _mergeAndProcessApiData(downBoundData, upBoundData, targetName);

      setState(() {
        _currentTimetableData = processedData;
        _isTimetableLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is DioException) {
          _errorMessage = "서버 오류: ${e.response?.statusCode ?? '연결 실패'}";
        } else {
          _errorMessage = "오류 발생: ${e.toString()}";
        }
        _isTimetableLoading = false;
      });
    }
  }

  // 🚀 [핵심 수정] 인덱스 기반 병합 (Sequential Merge) + X 자동 삽입 로직
  Map<String, dynamic> _mergeAndProcessApiData(
      Map<String, dynamic> downBoundRaw,
      Map<String, dynamic> upBoundRaw,
      String targetName) {
    
    List<dynamic> downSchedules = downBoundRaw['data'] ?? [];
    List<dynamic> upSchedules = upBoundRaw['data'] ?? [];

    String title = _tabNames[_selectedTabIndex];
    List<String> notes =
        List<String>.from(downBoundRaw['viaStopsSummary'] ?? []);

    // UI 이미지에 맞춘 5개 컬럼 헤더
    List<String> headers = ["순", "캠퍼스 출발", "$targetName 도착", "캠퍼스 도착", "비고"];

    List<List<String>> rows = [];
    List<int> highlightedRows = [];

    // 가장 긴 노선의 길이를 기준으로 반복 (균형 맞추기)
    int maxCount = max(downSchedules.length, upSchedules.length);

    // 1. 검색 키워드 리스트 준비
    List<String> rawKeywords = _stationAliases[targetName] ?? [targetName];
    List<String> searchKeywords =
        rawKeywords.map((k) => k.replaceAll(' ', '')).toList();

    for (int i = 0; i < maxCount; i++) {
      // 해당 인덱스에 데이터가 없으면 null, 있으면 객체
      var downItem = (i < downSchedules.length) ? downSchedules[i] : null;
      var upItem = (i < upSchedules.length) ? upSchedules[i] : null;

      // --- 1. 캠퍼스 출발 (하행) ---
      String campusDeparture =
          downItem != null ? (downItem['departureTime'] ?? '---') : '---';

      // --- 2. 역/터미널 도착 (하행) ---
      String stationArrival = '---';
      if (downItem != null) {
        String finalDest = (downItem['arrival'] ?? '').toString().replaceAll(' ', '');
        String arrivalTime = downItem['arrivalTime'] ?? '---';
        bool isFound = false;

        // 2-1. 최종 도착지 또는 경유지 시간 검색 (가장 적절한 도착 시간 찾기)
        List<dynamic> viaStops = downItem['viaStops'] ?? [];
        for (var stop in viaStops) {
            String stopName = (stop['name'] ?? '').toString().replaceAll(' ', '');
            for (String keyword in searchKeywords) {
              if (stopName.contains(keyword) || keyword.contains(stopName)) {
                if (stop['time'] != null && stop['time'] != "X") {
                  stationArrival = stop['time']; // 경유지 시간 사용
                  isFound = true;
                  break;
                }
              }
            }
            if (isFound) break;
        }
        
        // 2-2. 경유지에서 못 찾았다면, 최종 도착 시간 사용 (X 포함)
        if (!isFound) {
            stationArrival = arrivalTime; 
        }
      }

      // --- 3. 캠퍼스 도착 (상행) ---
      // 상행 데이터가 없으면 '---'로 균형을 맞춥니다.
      String campusArrival =
          upItem != null ? (upItem['arrivalTime'] ?? '---') : '---';

      // --- 4. 비고 (하행/상행 노트를 합칩니다) ---
      String note = "";
      if (downItem != null) {
          note = downItem['note'] ?? "";
          if (downItem['fridayOperates'] == false) note = "$note 금(X)".trim();
      }
      if (upItem != null) {
          // 상행 노트 추가 (중복 방지를 위해 간단히)
          if (note.isEmpty) {
              note = upItem['note'] ?? "";
          }
          if (upItem['fridayOperates'] == false && !note.contains("금(X)")) {
              note = "$note 금(X)".trim();
          }
      }
      if (note.isEmpty) note = '---'; // 노트도 없으면 --- 처리

      // 최종 행 데이터 추가
      rows.add([
        (i + 1).toString(),
        campusDeparture,
        stationArrival,
        campusArrival,
        note
      ]);
    }

    return {
      "title": title,
      "notes": notes,
      "headers": headers,
      "rows": rows,
      "highlightedRows": []
    };
  }


  // --- UI Build Section (기존 유지) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderImage(),
              SizedBox(height: 16),
              Text(
                '셔틀 시간표',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202020),
                ),
              ),
              SizedBox(height: 24),
              _buildTabGrid(),
              SizedBox(height: 24),
              _buildTimetableContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Image.asset(
      'assets/icons/timetable_header.png',
      width: 48,
      height: 48,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.calendar_month, size: 48, color: Colors.blue);
      },
    );
  }

  Widget _buildTabGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: _tabNames.length,
      itemBuilder: (context, index) {
        bool isSelected = _selectedTabIndex == index;
        return GestureDetector(
          onTap: () => _loadTimetableFor(index),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.blue[800]!, width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Text(
              _tabNames[index],
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue[800] : Colors.grey[700],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimetableContent() {
    if (_isTimetableLoading) {
      return Container(
          height: 300,
          alignment: Alignment.center,
          child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Container(
          height: 300,
          alignment: Alignment.center,
          child: Text(_errorMessage,
              style: TextStyle(fontSize: 16, color: Colors.red)));
    }
    if (_selectedTabIndex == -1 || _currentTimetableData == null) {
      return Container(
          height: 300,
          alignment: Alignment.center,
          child: Text('조회할 노선을 선택하세요.',
              style: TextStyle(fontSize: 16, color: Colors.grey)));
    }
    return _buildDynamicTimetable(_currentTimetableData!);
  }

  Widget _buildDynamicTimetable(Map<String, dynamic> data) {
    final String title = data['title'] ?? '시간표';
    final List<String> notes = List<String>.from(data['notes'] ?? []);
    final List<String> headers = List<String>.from(data['headers'] ?? []);
    final List<List<String>> rows = (data['rows'] as List<dynamic>?)
            ?.map((row) => List<String>.from(row))
            .toList() ??
        [];

    double headerFontSize = headers.length > 8 ? 9.0 : 10.0;
    double bodyFontSize = headers.length > 8 ? 10.0 : 11.0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue[700], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 8),
          ...notes.map((note) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(note,
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.9))))),
          SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.white.withOpacity(0.5)),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2)),
                children: headers
                    .map((header) => _buildTableCell(header,
                        isHeader: true, fontSize: headerFontSize))
                    .toList(),
              ),
              ...rows.map((row) {
                return TableRow(
                  children: row
                      .map((cell) => _buildTableCell(cell,
                          isX: cell.contains('X'), fontSize: bodyFontSize))
                      .toList(),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, bool isX = false, double fontSize = 11.0}) {
    Color textColor = Colors.white;
    if (isX || text == '---' || text == 'N/A' || text == 'N/KA' || text == 'X') {
      textColor = Colors.white.withOpacity(0.6);
    } else if (text.contains('하교시') || text.contains('중간노선')) {
      textColor = Colors.yellowAccent[400]!;
    }

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: textColor,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize),
      ),
    );
  }
}