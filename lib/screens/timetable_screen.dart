import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart'; // Dio 패키지
import 'dart:math'; // max 함수 사용을 위해 필수
import '../api/dio_client.dart'; // DioClient 경로에 맞게 수정해주세요
// 현재 아산터미널 조회시 8:55분 도착이 없어서 컬럼이 한칸씩 밀리고 이후 컬럼을 필요 없는데 로직이 알아서 컬럼을 채우면서 오류남 // 밥 먹고 수정할 것
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

            final downBoundRaw = results[0].data;
            final upBoundRaw = results[1].data;

            final processedData =
                _mergeAndProcessApiData(downBoundRaw, upBoundRaw, targetName);

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

    // 🚀 [핵심 수정] 천안 터미널/역/아산역 로직 유지, 온양역은 기본 로직(else) 사용
    Map<String, dynamic> _mergeAndProcessApiData(
        Map<String, dynamic> downBoundRaw,
        Map<String, dynamic> upBoundRaw,
        String targetName) {

        List<dynamic> downSchedules = downBoundRaw['data'] ?? [];
        List<dynamic> upSchedules = upBoundRaw['data'] ?? [];

        String title = _tabNames[_selectedTabIndex];
        List<String> notes =
            List<String>.from(downBoundRaw['viaStopsSummary'] ?? []);

        List<String> headers = ["순", "캠퍼스 출발", "$targetName 도착", "캠퍼스 도착", "비고"];

        // 최대 오프셋 계산 (행 개수를 맞추기 위함)
        int maxDownOffset = 0;
        if (targetName == '천안 터미널') maxDownOffset = 9; // 원본 코드 (2~10행 X 처리) 기준
        else if (targetName == '천안역') maxDownOffset = 8; // 2행~9행 (8개)를 'X'로 처리
        else if (targetName == '천안 아산역') maxDownOffset = 7; // 2행~8행 (7개)를 'X'로 처리
        // 온양역은 오프셋 없음 (0)

        // 37~44행 (8개) 삭제를 반영하여 maxCount 계산
        int upSchedulesCount = upSchedules.length;
        if (targetName == '천안 터미널' && upSchedulesCount > 36) {
            upSchedulesCount = upSchedulesCount - 8; // 37~44행 (8개) 삭제
        }

        int maxCount = max(downSchedules.length + maxDownOffset, upSchedulesCount);


        List<List<String>> rows = [];

        for (int i = 0; i < maxCount; i++) {

            // ⭐️ 37~44행 삭제 로직: 천안 터미널일 경우, 인덱스 36부터 43까지 건너뜀 (순번 37~44)
            if (targetName == '천안 터미널' && i >= 36 && i <= 43) {
                continue;
            }

            var upItem = (i < upSchedules.length) ? upSchedules[i] : null;

            var downItem;
            String campusDeparture = ' ';
            String stationArrival = 'X';
            String campusArrival = '---';
            String finalNote = ' ';

            // 1. Upbound 데이터 추출
            campusArrival = upItem != null ? (upItem['arrivalTime'] ?? '---') : '---';
            String upDepartureFromAPI = upItem != null ? (upItem['departureTime'] ?? '---') : '---';

            // 2. Downbound 데이터 인덱스 및 컬럼 값 결정

            // 2-A. 아산역 (2~8행 X 오버라이드)
            if (targetName == '천안 아산역') {
                if (i >= 1 && i <= 7) {
                    downItem = null;
                    campusDeparture = 'X';
                    stationArrival = upDepartureFromAPI;
                } else {
                    int downIndex = i;
                    if (i >= 8) { // 9행부터는 하행 인덱스 보정
                        downIndex = i - 7;
                    }
                    downItem = (downIndex >= 0 && downIndex < downSchedules.length) ? downSchedules[downIndex] : null;
                }
            }

            // 2-B. 천안역 (2~9행 X 오버라이드)
            else if (targetName == '천안역') {
                if (i >= 1 && i <= 8) { // 2~9행 (i=1~8): 하행 데이터 무시
                    downItem = null;
                    campusDeparture = 'X';
                    stationArrival = upDepartureFromAPI;
                } else { // i=0 (1행) 또는 i >= 9 (10행부터)
                    int downIndex = i;
                    if (i >= 9) { // 10행부터는 하행 인덱스 보정
                        downIndex = i - 8;
                    }
                    downItem = (downIndex >= 0 && downIndex < downSchedules.length) ? downSchedules[downIndex] : null;
                }
            }

            // 2-C. 🚀 천안 터미널 (2~10행 X 오버라이드 로직 적용 및 37~44행 삭제)
            else if (targetName == '천안 터미널') {
                if (i >= 1 && i <= 9) { // 2~10행 (i=1~9): 하행 데이터 무시 (X 처리)
                    downItem = null;
                    campusDeparture = 'X';
                    stationArrival = upDepartureFromAPI;
                } else { // i=0 (1행) 또는 i >= 10 (11행부터)
                    int downIndex = i;

                    if (i >= 10) { // 11행(i=10)부터는 하행 인덱스 보정 (i - 9)
                        downIndex = i - 9;
                    }

                    // 37~44행 삭제로 인해 하행 인덱스가 추가로 밀리는 것을 보정
                    if (i >= 44) {
                        downIndex = i - 17;
                    }

                    downItem = (downIndex >= 0 && downIndex < downSchedules.length) ? downSchedules[downIndex] : null;
                }
            }

            // 2-D. 온양역 및 기타 (순차 병합) - 백엔드 데이터 순서 그대로 사용
            else {
                downItem = (i < downSchedules.length) ? downSchedules[i] : null;
            }

            // 3. Downbound 컬럼 값 설정 (오버라이드 구간 외)
            if (downItem != null) {
                String downArrivalFromAPI = downItem['arrivalTime'] ?? 'X';

                // campusDeparture는 이미 downItem에서 추출됨
                if (campusDeparture == ' ') campusDeparture = downItem['departureTime'] ?? 'X';
                stationArrival = downArrivalFromAPI;

                // API 도착/출발 시간 일치 체크 (천안 아산역만)
                if (targetName == '천안 아산역' && upItem != null) {
                    if (downArrivalFromAPI == upDepartureFromAPI && downArrivalFromAPI != 'X') {
                        stationArrival = downArrivalFromAPI;
                    }
                }
            }

            // 4. 시간 역전 체크 (모든 행에 적용)
            bool isDownValid = campusDeparture != 'X' && campusDeparture != '---' && campusDeparture != ' ';
            bool isUpValid = campusArrival != '---' && campusArrival != 'X' && campusArrival != ' ';

            if (isDownValid && isUpValid) {
                try {
                    final depParts = campusDeparture.split(':');
                    final arrParts = campusArrival.split(':');

                    final departure = int.parse(depParts[0]) * 60 + int.parse(depParts[1]);
                    final arrival = int.parse(arrParts[0]) * 60 + int.parse(arrParts[1]);

                    // 출발 시간이 도착 시간보다 늦거나 같으면 (시간 역전 시)
                    if (departure >= arrival) {
                        campusDeparture = 'X';
                    }
                } catch (e) { /* 파싱 오류 무시 */ }
            }

            // 5. 누락 데이터 처리 (Upbound 데이터 복구)
            if (downItem == null && campusDeparture != 'X') {
                if (upItem != null) {
                    // Downbound 데이터 누락 시 상행 데이터로 복구 (Proxy)
                    campusDeparture = upDepartureFromAPI;
                    stationArrival = upDepartureFromAPI;
                } else {
                    campusDeparture = 'X';
                    stationArrival = 'X';
                }
            } else if (downItem == null && campusDeparture == ' ') {
                // downItem이 null이고 2-10행 오버라이드를 거치지 않은 경우
                campusDeparture = 'X';
                stationArrival = 'X';
            }

            // 6. 비고 처리 (금요일 운행 여부만)
            String fridayNote = '';
            if (downItem != null && downItem['fridayOperates'] == false) {
                fridayNote = "금(X)";
            } else if (upItem != null && upItem['fridayOperates'] == false) {
                fridayNote = "금(X)";
            }
            finalNote = fridayNote;
            if (finalNote.isEmpty) finalNote = ' ';

            // 최종 행 데이터 추가
            rows.add([
                (i + 1).toString(),
                campusDeparture,
                stationArrival,
                campusArrival,
                finalNote
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