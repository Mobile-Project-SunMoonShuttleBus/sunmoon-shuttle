import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart'; // Dio 패키지 사용
import '../api/dio_client.dart'; // 1번 코드의 DioClient

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  int _selectedTabIndex = -1; 
  
  final List<String> _tabNames = [
    '아산(KTX)역', 
    '천안역',      
    '천안 터미널', 
    '온양 터미널/역' 
  ];
  
  final Map<int, String> _tabApiArrivalNames = {
    0: '천안 아산역', 
    1: '천안역',
    2: '천안 터미널',
    3: '온양온천역' 
  };
  
  bool _isTimetableLoading = false;
  Map<String, dynamic>? _currentTimetableData; 
  String _errorMessage = "";

  void _loadTimetableFor(int index) {
    if (_selectedTabIndex == index) return; 

    final String arrivalName = _tabApiArrivalNames[index]!; 
    
    setState(() {
      _selectedTabIndex = index;
      _isTimetableLoading = true;
      _currentTimetableData = null; 
      _errorMessage = ""; 
    });

    _fetchTimetableData(arrivalName);
  }

  // --- [핵심 수정] DioClient로 교체 ---
  Future<void> _fetchTimetableData(String arrivalName) async {
    // 1. 토큰 수동 확인 로직 삭제 (DioClient가 알아서 함)

    try {
      // 2. DioClient 사용 (http 대신)
      // 토큰 자동 주입, Base URL 자동 적용
      final response = await DioClient.instance.get(
        '/api/shuttle/schedules',
        queryParameters: {
          'dayType': '평일',
          'departure': '아산캠퍼스', 
          'arrival': arrivalName,    
          'limit': '0' 
        },
      );

      if (!mounted) return;

      // 3. 데이터 처리
      // Dio는 response.data가 이미 JSON 파싱된 상태(Map/List)임
      final rawData = response.data;
      final processedData = _processRawApiData(rawData, arrivalName);

      setState(() {
        _currentTimetableData = processedData;
        _isTimetableLoading = false;
      });

    } catch (e) {
      // 에러 처리
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

  Map<String, dynamic> _processRawApiData(Map<String, dynamic> rawData, String arrivalName) {
    List<dynamic> schedules = rawData['data'] ?? [];
    String title = _tabNames[_selectedTabIndex]; 
    List<String> notes = List<String>.from(rawData['viaStopsSummary'] ?? []);
    List<String> headers = ["순", "캠퍼스 출발", "$arrivalName 도착", "캠퍼스 도착", "비고"];

    List<List<String>> rows = [];
    List<int> highlightedRows = []; 

    int index = 1;
    for (var schedule in schedules) {
      String arrivalTimeToDisplay = "N/A";
      List<dynamic> viaStops = schedule['viaStops'] ?? [];
      
      var foundStop = viaStops.firstWhere(
        (stop) => stop['name'] == arrivalName,
        orElse: () => null,
      );

      if (foundStop != null) {
        arrivalTimeToDisplay = foundStop['time'] ?? 'N/KA';
      } else if (schedule['arrival'] == arrivalName) {
        arrivalTimeToDisplay = schedule['arrivalTime'] ?? 'N/KA';
      }
      
      rows.add([
        (index++).toString(),
        schedule['departureTime'] ?? 'N/A', 
        arrivalTimeToDisplay, 
        schedule['arrivalTime'] ?? 'N/A', 
        schedule['note'] ?? (schedule['fridayOperates'] == false ? '금(X)' : '') 
      ]);
    }

    return {
      "title": title,
      "notes": notes,
      "headers": headers,
      "rows": rows,
      "highlightedRows": highlightedRows 
    };
  }
  
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
              // 헤더 이미지 (없으면 아이콘으로 대체하는 안전장치 추가)
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

  // 이미지 에러 방지용 헬퍼
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
          onTap: () {
            _loadTimetableFor(index);
          },
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
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Text(
          _errorMessage,
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      );
    }
    
    if (_currentTimetableData == null) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Text(
          '조회할 노선을 선택하세요.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return _buildDynamicTimetable(_currentTimetableData!);
  }

  Widget _buildDynamicTimetable(Map<String, dynamic> data) {
    final String title = data['title'] ?? '시간표';
    final List<String> notes = List<String>.from(data['notes'] ?? []);
    final List<String> headers = List<String>.from(data['headers'] ?? []);
    final List<List<String>> rows = (data['rows'] as List<dynamic>?)
        ?.map((row) => List<String>.from(row))
        .toList() ?? [];
    final List<int> highlightedRows = List<int>.from(data['highlightedRows'] ?? []);

    double headerFontSize = 10.0;
    double bodyFontSize = 11.0;
    if (headers.length > 8) {
      headerFontSize = 9.0;
      bodyFontSize = 10.0;
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          
          ...notes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  note,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9)),
                ),
              )),
          SizedBox(height: 16),

          Table(
            border: TableBorder.all(color: Colors.white.withOpacity(0.5)),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2)),
                children: headers.map((header) {
                  return _buildTableCell(header, isHeader: true, fontSize: headerFontSize);
                }).toList(),
              ),
              
              ...rows.asMap().entries.map((entry) { 
                int rowIndex = entry.key;
                List<String> row = entry.value;
                bool isHighlighted = highlightedRows.contains(rowIndex);

                return TableRow(
                  decoration: BoxDecoration(
                    color: isHighlighted ? Colors.white.withOpacity(0.25) : null,
                  ),
                  children: row.map((cell) {
                    return _buildTableCell(cell, isX: cell.contains('X'), fontSize: bodyFontSize);
                  }).toList(),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isX = false, double fontSize = 11.0}) {
    Color textColor = Colors.white; 
    
    if (isX) {
      textColor = Colors.white.withOpacity(0.6);
    } else if (text.contains('하교시') || text.contains('중간노선') || text.contains('경유') || text.contains('소요')) {
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
          fontSize: fontSize,
        ),
      ),
    );
  }
}