import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart'; // Dio 패키지 (구조 유지)
import 'dart:math'; // max 함수 (구조 유지)
// import '../api/dio_client.dart'; // API 요청 제거

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

  // 2. API 요청 시 사용할 정확한 도착지/출발지 명칭 (UI 헤더용으로만 사용)
  final Map<int, String> _tabApiArrivalNames = {
    0: '천안 아산역',
    1: '천안역',
    2: '천안 터미널',
    3: '온양역/아산터미널'
  };

  // 3. 백엔드 데이터와 매칭할 다양한 이름들 (하드코딩 시 불필요하나 구조 유지)
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

    _currentTimetableData = _getHardcodedTimetable(targetName);

    setState(() {
      _isTimetableLoading = false;
    });
  }

  Future<void> _fetchTimetableData(String targetName) async {
    // API 호출 로직 제거
  }

  // ⭐️ [핵심 수정] 하드코딩된 시간표 데이터 함수
  Map<String, dynamic> _getHardcodedTimetable(String targetName) {
    List<String> headers = ["순", "캠퍼스 출발", "$targetName 도착", "캠퍼스 도착", "비고"];
    List<List<String>> rows = [];
    String title = _tabNames[_selectedTabIndex];

    // --- 1. 아산(KTX)역 시간표 (스크린샷 38행 데이터 적용) ---
    if (targetName == '천안 아산역') {
      title = '아산(KTX)역';
      // 이 데이터는 이미 하드코딩되어 있습니다. (38행)
      rows = [
        ['1', '08:10', '08:25', '08:40', ''],
        ['2', 'X', 'X', '08:50', '금(X)'],
        ['3', 'X', 'X', '09:05', '금(X)'],
        ['4', 'X', 'X', '09:15', '금(X)'],
        ['5', 'X', 'X', '09:20', '금(X)'],
        ['6', 'X', 'X', '09:25', '금(X)'],
        ['7', '09:40', '09:55', '10:10', ''],
        ['8', '09:50', '10:05', '10:20', '금(X)'],
        ['9', '10:00', '10:15', '10:30', '금(X)'],
        ['10', '10:30', '10:45', '11:00', '금(X)'],
        ['11', '10:40', '10:55', '11:10', ''],
        ['12', '10:50', '11:05', '11:20', '금(X)'],
        ['13', '11:00', '11:15', '11:30', '금(X)'],
        ['14', '11:30', '11:45', '12:00', '금(X)'],
        ['15', '11:40', '11:55', '12:10', ''],
        ['16', '11:50', '12:05', '12:20', '금(X)'],
        ['17', '12:30', '12:45', '13:00', '금(X)'],
        ['18', '12:40', '12:55', '13:10', ''],
        ['19', '12:50', '13:05', '13:20', '금(X)'],
        ['20', '13:30', '13:45', '14:00', '금(X)'],
        ['21', '13:40', '13:55', '14:10', ''],
        ['22', '14:30', '14:45', '15:00', '금(X)'],
        ['23', '14:40', '14:55', '15:10', ''],
        ['24', '15:30', '15:45', '16:00', '금(X)'],
        ['25', '15:40', '15:55', '16:10', ''],
        ['26', '15:50', '16:05', '16:20', '금(X)'],
        ['27', '16:30', '16:45', '17:00', '금(X)'],
        ['28', '16:40', '16:55', '17:10', ''],
        ['29', '16:50', '17:05', '17:20', '금(X)'],
        ['30', '17:30', '17:45', '18:00', '금(X)'],
        ['31', '17:40', '17:55', '18:10', ''],
        ['32', '17:50', '18:05', '18:20', '금(X)'],
        ['33', '18:30', '18:45', '19:00', ''],
        ['34', '18:40', '18:55', '19:10', '금(X)'],
        ['35', '18:50', '19:05', '19:20', '금(X)'],
        ['36', '19:30', '19:45', '20:00', ''],
        ['37', '20:30', '20:45', '21:00', ''],
        ['38', '21:30', '21:45', '22:00', ''],
      ];

    // --- 2. 천안역 시간표 (스크린샷 40행 데이터 적용) ---
    } else if (targetName == '천안역') {
      title = '천안역';
      // '스크린샷 2025-12-06 144920.png' 기반
      // 천안역 시간은 '천안역' 출발시간 사용, 경유지 제거
      rows = [
        ['1', '7:40', '8:10', '8:40', ''],
        ['2', '8:20', '8:50', '8:50', '금(X)'],
        ['3', 'X', '8:25', '9:00', '금(X)'],
        ['4', 'X', '8:35', '9:05', '금(X)'],
        ['5', 'X', '8:40', '9:10', '금(X)'],
        ['6', 'X', '8:50', '9:15', '금(X)'],
        ['7', 'X', '8:55', '9:20', ''],
        ['8', 'X', '9:00', '9:25', ''],
        ['9', 'X', '9:00', '9:30', '금(X)'],
        ['10', '9:30', '9:55', '10:20', '금(X)'],
        ['11', '9:35', '10:00', '10:25', '금(X)'],
        ['12', '10:30', '10:55', '11:20', ''],
        ['13', '10:35', '11:00', '11:25', '금(X)'],
        ['14', '10:40', '11:05', '11:30', '금(X)'],
        ['15', '11:30', '11:55', '12:20', ''],
        ['16', '11:35', '12:00', '12:25', '금(X)'],
        ['17', '11:40', '12:05', '12:30', '금(X)'],
        ['18', '12:30', '12:55', '13:20', ''],
        ['19', '12:35', '13:00', '13:25', '금(X)'],
        ['20', '13:30', '13:55', '14:20', '금(X)'],
        ['21', '13:35', '14:00', '14:25', '금(X)'],
        ['22', '13:40', '14:05', '14:30', '금(X)'],
        ['23', '14:20', '14:45', '15:20', ''],
        ['24', '14:30', '14:55', '15:25', '금(X)'],
        ['25', '14:40', '15:00', '15:30', '金(X)'],
        ['26', '15:30', '15:55', '16:20', '金(X)'],
        ['27', '15:35', '16:00', '16:25', '금(X)'],
        ['28', '15:40', '16:05', '16:30', '금(X)'],
        ['29', '16:20', '16:50', '17:20', '금(X)'],
        ['30', '16:30', '16:55', '17:25', '金(X)'],
        ['31', '16:40', '17:05', '17:30', '금(X)'],
        ['32', '17:20', '17:55', '18:20', ''],
        ['33', '17:30', '18:00', '18:25', '금(X)'],
        ['34', '17:40', '18:05', '18:30', '금(X)'],
        ['35', '18:30', '18:55', '19:20', ''],
        ['36', '18:35', '19:00', '19:25', '금(X)'],
        ['37', '18:40', '19:05', '19:30', ''],
        ['38', '19:30', '19:55', '20:20', ''],
        ['39', '20:30', '20:55', '21:30', ''],
        ['40', '21:30', '21:55', '22:20', ''],
      ];

    // --- 3. 천안 터미널 시간표 (스크린샷 40행 데이터 적용) ---
    } else if (targetName == '천안 터미널') {
      title = '천안 터미널';
      // '스크린샷 2025-12-06 144955.png' 기반
      // 터미널 시간은 '터미널' 열의 시간 사용 (X 및 소요시간 포함)
      rows = [
        ['1', '7:30', '8:05', '8:40', '금(X)'],
        ['2', 'X', '8:15', '8:50', '금(X)'],
        ['3', 'X', '8:25', '9:00', '금(X)'],
        ['4', 'X', '8:30', '9:05', '금(X)'],
        ['5', 'X', '8:35', '9:10', '금(X)'],
        ['6', 'X', '8:40', '9:15', '금(X)'],
        ['7', 'X', '8:45', '9:20', '금(X)'],
        ['8', 'X', '8:50', '9:25', '금(X)'],
        ['9', 'X', '8:50', '9:25', '금(X)'],
        ['10', '9:30', '10:00', '10:30', '금(X)'],
        ['11', '9:40', '10:10', '10:40', '금(X)'],
        ['12', '10:20', '10:50', '11:20', '금(X)'],
        ['13', '10:30', '11:00', '11:30', '금(X)'],
        ['14', '10:40', '11:10', '11:40', '금(X)'],
        ['15', '11:20', '11:50', '12:20', '금(X)'],
        ['16', '11:30', '12:00', '12:30', '금(X)'],
        ['17', '11:40', '12:10', '12:40', '금(X)'],
        ['18', '12:20', '12:50', '13:20', '금(X)'],
        ['19', '12:30', '13:00', '13:30', '금(X)'],
        ['20', '13:30', '13:50', '14:20', '금(X)'],
        ['21', '13:20', '13:50', '14:20', '금(X)'],
        ['22', '13:40', '14:10', '14:40', '금(X)'],
        ['23', '14:20', '14:50', '15:20', '금(X)'],
        ['24', '14:30', '15:00', '15:30', '금(X)'],
        ['25', '14:40', '15:10', '15:40', '금(X)'],
        ['26', '15:20', '15:50', '16:20', '금(X)'],
        ['27', '15:30', '16:00', '16:30', '금(X)'],
        ['28', '15:40', '16:10', '16:40', '금(X)'],
        ['29', '16:20', '16:50', '17:20', '금(X)'],
        ['30', '16:30', '17:00', '17:30', '금(X)'],
        ['31', '16:40', '17:10', '17:40', '금(X)'],
        ['32', '17:20', '17:50', '18:20', '금(X)'],
        ['33', '17:30', '18:00', '18:30', '금(X)'],
        ['34', '17:40', '18:10', '18:40', '금(X)'],
        ['35', '18:30', '19:00', '19:30', '금(X)'],
        ['36', '18:40', '19:10', '19:40', '금(X)'],
        ['37', '18:50', '19:20', '19:50', '금(X)'],
        ['38', '19:30', '20:00', '20:30', '금(X)'],
        ['39', '20:30', '21:00', '21:30', '금(X)'],
        ['40', '21:30', '22:00', '22:30', '금(X)'],
      ];

    // --- 4. 온양 터미널/역 시간표 (스크린샷 7행 데이터 적용) ---
    } else if (targetName == '온양역/아산터미널') {
      title = '온양 터미널/역';
      // '스크린샷 2025-12-06 145041.png' 기반
      // 온양역/아산터미널 도착 시간은 '온양온천역' 시간 사용
      rows = [
        ['1', 'X', '8:10', '8:40', ''],
        ['2', 'X', '8:45', '9:15', '금(X)'],
        ['3', 'X', '8:50', '9:20', ''],
        ['4', '10:25', '10:55', '11:20', ''],
        ['5', '15:30', '16:00', '16:25', ''],
        ['6', '17:30', '18:00', '18:25', '금(X)'],
        ['7', '18:30', '19:00', '19:05', ''],
      ];
    }

    return {
      "title": title,
      "notes": ['* 백엔드 API 대신 스크린샷 데이터를 기반으로 하드코딩되었습니다.'],
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