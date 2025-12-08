import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../api/dio_client.dart';
import '../api/notice_api.dart';
import '../models/shuttle_notice_models.dart';
import 'notice/shuttle_notice_list_screen.dart'; // 셔틀 공지 화면
import 'notice/shuttle_notice_detail_screen.dart'; // 셔틀 공지 상세 화면
import 'notice/bus_notices_screen.dart'; // 셔틀버스 공지 화면 (새로 추가)

class MainMapPage extends StatefulWidget {
  const MainMapPage({super.key});

  @override
  _MainMapPageState createState() => _MainMapPageState();
}

class _MainMapPageState extends State<MainMapPage> {
  NaverMapController? _mapController;
  Timer? _refreshTimer;
  
  // ⭐️ [Mocking Logic] 테스트 시 true, 실제 사용 시 false
  static const bool IS_MOCKING_LOCATION = true; 
  // ⭐️ [Mocking Point] 천안역 근처 좌표로 설정 (학교 외부)
  static const NLatLng MOCK_START_POINT = NLatLng(36.798628, 127.074679); 

  // 위치 및 경로 관련
  StreamSubscription<Position>? _positionStreamSubscription;
  NLatLng? _currentUserPosition; 
  
  // 셔틀 정류장 최종 좌표 (학교 내부 도착점)
  static const NLatLng SCHOOL_SHUTTLE_STOP = NLatLng(36.8003353, 127.0713667); 
  // 학교 내부/외부 판단을 위한 거리 기준 (미터)
  static const double SCHOOL_BOUNDARY_RADIUS_M = 600.0; 
  // 외부 셔틀장 경로 안내 최대 거리 (미터)
  static const double MAX_WALKING_DISTANCE_M = 500.0; 
  
  // [경로 노드] 순서 상관없이 경로를 구성하는 지점들 (학교 내부 도보 경로에만 사용됨)
  static const List<NLatLng> ROUTE_TO_STOP = [
    NLatLng(36.798000, 127.074000), // Node 0
    NLatLng(36.798500, 127.073500), // Node 1
    NLatLng(36.799000, 127.072500), // Node 2
    NLatLng(36.800000, 127.071500), // Node 3
  ];

  // [외부 셔틀 승차장] 각 역/터미널의 셔틀장 좌표
  static const List<NLatLng> EXTERNAL_STOPS = [
    NLatLng(36.794978, 127.103806), // 아산(KTX)역 [Index 0]
    NLatLng(36.809727, 127.145230), // 천안역 [Index 1]
    NLatLng(36.8220, 127.1810),     // 천안터미널 [Index 2]
    NLatLng(36.7860, 127.0020),     // 온양터미널/역 [Index 3]
  ];

  final Set<NMarker> _markers = {}; 

  // UI 상태
  int _selectedStationIndex = 0;
  final List<String> _stationNames = ['아산(KTX)역', '천안역', '천안터미널', '온양터미널/역'];
  
  // UI 표시 정보
  bool _isLoading = true;
  String _nextDepartureTime = "조회 중..."; 
  String _timeRemaining = ""; 
  
  String _walkingDistance = "- m"; 
  String _walkingTime = "- 분"; 
  
  // 선택된 목적지가 500m 밖에 있는지 여부
  bool _isTooFar = false; 

  static const double _WALKING_SPEED = 80; // 분당 80m

  // 셔틀 공지 관련
  final NoticeApi _noticeApi = NoticeApi.I;
  ShuttleNoticeSummary? _latestNotice;
  bool _isLoadingNotice = false;

  // 초기 카메라 (학교 승강장 근처)
  static const NCameraPosition _initialCameraPosition = NCameraPosition(
    target: SCHOOL_SHUTTLE_STOP,
    zoom: 15.5,
  );
  
  // ⭐️ [하드코딩된 시간표] 역/터미널 -> 캠퍼스 출발 시간표 (학교 외부용)
  static const Map<String, List<String>> _STATION_DEP_TIMES = {
    '아산(KTX)역': [
      '08:25', '08:45', '08:55', '09:00', '09:10', '09:55', '10:10', '11:10', 
      '11:55', '12:55', '14:00', '15:00', '16:00', '17:00', '18:00', '18:55', 
      '20:05', '21:00', '21:30'
    ],
    // ⭐️ 15시 31분 이후의 다음 차로 15:50을 반영 (수정된 데이터)
    '천안역': [
      '08:15', '08:40', '08:50', '09:00', '10:00', '10:50', '11:50', '13:10', 
      '13:20', '14:20', '15:30', 
      '15:50', // ⬅️ 다음 차로 15:50을 반영
      '17:00', '18:05', '18:30', '19:05', '19:25', 
      '19:55', '20:55', '21:45'
    ],
    '천안터미널': [
      '08:15', '08:25', '08:35', '08:45', '08:55', '09:30', '10:40', '11:40', 
      '13:10', '14:00', '14:10', '15:10', '15:20', '16:10', '17:20', '18:20', 
      '19:20', '20:10', '21:10', '22:00'
    ],
    '온양터미널/역': [
      '08:10', '08:40', '10:55', '16:00', '19:00'
    ],
  };

  @override
  void initState() {
    super.initState();
    
    // ⭐️ [추가] 초기 로딩 시 현재 위치와 가장 가까운 역을 선택
    if (IS_MOCKING_LOCATION) {
        double minDistance = double.infinity;
        int bestIndex = 0;
        
        for (int i = 0; i < EXTERNAL_STOPS.length; i++) {
            final dist = _calculateDistance(MOCK_START_POINT, EXTERNAL_STOPS[i]);
            if (dist < minDistance) {
                minDistance = dist;
                bestIndex = i;
            }
        }
        _selectedStationIndex = bestIndex;
    }
    
    _checkPermissionAndListenLocation();
    
    _fetchBusData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchBusData());
    
    // 최신 셔틀 공지 로드
    _loadLatestNotice();
  }

  // 최신 셔틀 공지 1개 로드
  Future<void> _loadLatestNotice() async {
    if (_isLoadingNotice) return;
    
    setState(() {
      _isLoadingNotice = true;
    });

    try {
      final notices = await _noticeApi.fetchShuttleNotices();
      if (mounted && notices.isNotEmpty) {
        setState(() {
          _latestNotice = notices.first; // 최신 공지 (첫 번째)
          _isLoadingNotice = false;
        });
      } else {
        setState(() {
          _latestNotice = null;
          _isLoadingNotice = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('최신 공지 로드 실패: $e');
      }
      if (mounted) {
        setState(() {
          _latestNotice = null;
          _isLoadingNotice = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  double _calculateDistance(NLatLng p1, NLatLng p2) {
    return Geolocator.distanceBetween(
      p1.latitude, p1.longitude,
      p2.latitude, p2.longitude,
    );
  }
  
  bool _isUserInsideSchool() {
    if (_currentUserPosition == null) return false;
    
    final distance = _calculateDistance(_currentUserPosition!, SCHOOL_SHUTTLE_STOP);
    return distance < SCHOOL_BOUNDARY_RADIUS_M;
  }
  
  // ⭐️ 하드코딩된 시간표에서 현재 시간 이후 가장 빠른 출발 시간 찾기
  String _getStationDepartureTime(String stationName) {
    final List<String>? schedule = _STATION_DEP_TIMES[stationName];
    if (schedule == null || schedule.isEmpty) {
      return "시간표 없음";
    }

    final DateTime now = DateTime.now();
    
    for (String timeString in schedule) {
      try {
        final parts = timeString.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        DateTime departureTime = DateTime(now.year, now.month, now.day, hour, minute);
        
        if (departureTime.isAfter(now.subtract(const Duration(minutes: 1)))) {
           return timeString; // 현재 시각 이후의 가장 빠른 시간
        }
        
      } catch (e) {
        continue;
      }
    }
    
    return schedule.first;
  }

  int _findBestEntryNode(NLatLng currentPos) {
    int bestIndex = -1;
    double minDistanceToUser = double.infinity;
    double distToFinalStop = _calculateDistance(currentPos, SCHOOL_SHUTTLE_STOP);
    
    for (int i = 0; i < ROUTE_TO_STOP.length; i++) {
      NLatLng node = ROUTE_TO_STOP[i];
      double distanceToUser = _calculateDistance(currentPos, node);
      double distanceNodeToStop = _calculateDistance(node, SCHOOL_SHUTTLE_STOP);
      
      if ((distanceToUser + distanceNodeToStop) > (distToFinalStop * 1.5)) {
        continue;
      }

      if (distanceToUser < minDistanceToUser) {
        minDistanceToUser = distanceToUser;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _checkPermissionAndListenLocation() async {
    if (IS_MOCKING_LOCATION) {
        _positionStreamSubscription = Stream<Position>.periodic(const Duration(seconds: 2), (count) {
            return Position(
                latitude: MOCK_START_POINT.latitude,
                longitude: MOCK_START_POINT.longitude,
                timestamp: DateTime.now(),
                accuracy: 0.0,
                altitude: 0.0,
                heading: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
                altitudeAccuracy: 0.0,
                headingAccuracy: 0.0,
            );
        }).listen((Position position) {
            final newPos = NLatLng(position.latitude, position.longitude);
            _currentUserPosition = newPos;

            if (_mapController != null) {
                _updatePathToStop();
            }
        });
        return; 
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    final locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      final newPos = NLatLng(position.latitude, position.longitude);
      _currentUserPosition = newPos;

      if (_mapController != null) {
        try {
          _mapController!.getLocationOverlay()
            ..setPosition(newPos)
            ..setIsVisible(true);
        } catch (e) {}
        
        _updatePathToStop();
      }
    });
  }

  void _updatePathToStop() {
    if (_currentUserPosition == null || _mapController == null) return;

    List<NLatLng> pathCoords = [];
    NLatLng finalDestination;
    
    bool insideSchool = _isUserInsideSchool();
    
    if (insideSchool) {
      // MODE 1: 학교 내부 경로 안내 
      
      if (_isTooFar) {
          setState(() => _isTooFar = false);
      }
      
      finalDestination = SCHOOL_SHUTTLE_STOP;
      
      int entryIndex = _findBestEntryNode(_currentUserPosition!);
      
      if (entryIndex != -1) {
          if (_calculateDistance(_currentUserPosition!, finalDestination) < _calculateDistance(_currentUserPosition!, ROUTE_TO_STOP[entryIndex])) {
              pathCoords.add(finalDestination);
              gotoDrawPath(pathCoords, finalDestination);
              return;
          }

          NLatLng entryNode = ROUTE_TO_STOP[entryIndex];
          pathCoords.add(entryNode);
          NLatLng lastAddedPoint = entryNode;
          Set<int> visitedIndices = {entryIndex};
          
          while (visitedIndices.length < ROUTE_TO_STOP.length) {
              int nextNodeIndex = -1;
              double minDistance = double.infinity;
              
              for (int i = 0; i < ROUTE_TO_STOP.length; i++) {
                  if (visitedIndices.contains(i)) continue; 
                  
                  NLatLng candidateNode = ROUTE_TO_STOP[i];
                  double distance = _calculateDistance(lastAddedPoint, candidateNode);
                  
                  if (_calculateDistance(lastAddedPoint, finalDestination) < distance) {
                      nextNodeIndex = -2; 
                      break;
                  }
                  
                  if (distance < minDistance) {
                      minDistance = distance;
                      nextNodeIndex = i;
                  }
              }

              if (nextNodeIndex == -2 || nextNodeIndex == -1) { 
                  break;
              } else { 
                  lastAddedPoint = ROUTE_TO_STOP[nextNodeIndex];
                  pathCoords.add(lastAddedPoint);
                  visitedIndices.add(nextNodeIndex);
              }
          }
      }
      pathCoords.insert(0, _currentUserPosition!);
      
    } else {
      // MODE 2: 학교 외부 경로 안내 (거리 체크 로직 포함)
      
      finalDestination = EXTERNAL_STOPS[_selectedStationIndex];
      
      // 500m 거리 체크
      double distanceToStop = _calculateDistance(_currentUserPosition!, finalDestination);
      
      if (distanceToStop > MAX_WALKING_DISTANCE_M) {
        // 500m 초과 시: 지도 표시 금지, 메시지 표시 상태로 전환
        if (!_isTooFar) {
          setState(() {
              _isTooFar = true;
              // 지도 오버레이 클리어
              _mapController!.deleteOverlay(const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'path_to_stop'));
              _mapController!.clearOverlays(type: NOverlayType.marker);
              _walkingDistance = "- m"; 
              _walkingTime = "- 분";
          });
        }
        return; // 경로 그리기 함수 호출을 막음
      } else {
        // 500m 이내 시: 정상 경로 표시 상태로 전환
        if (_isTooFar) {
            setState(() => _isTooFar = false);
        }
        pathCoords.add(_currentUserPosition!);
      }
    }
    
    // '너무 멀다' 상태일 경우 경로를 그리지 않음
    if (_isTooFar) return;

    // 최종 목적지를 연결
    if (pathCoords.last != finalDestination) {
        pathCoords.add(finalDestination);
    }
    
    gotoDrawPath(pathCoords, finalDestination);
  }
  
  void gotoDrawPath(List<NLatLng> finalPathCoords, NLatLng finalDestination) {
    // 1. 거리 및 시간 계산 
    double dist = _calculateDistance(finalPathCoords.first, finalDestination);
    double actualDist = dist * (_isUserInsideSchool() ? 1.3 : 1.0); 
    int walkMin = (actualDist / _WALKING_SPEED).ceil();

    // 2. 폴리라인 초기화 및 그리기
    try { 
      _mapController!.deleteOverlay(const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'path_to_stop'));
    } catch (e) {}

    if (finalPathCoords.length >= 2) {
      final path = NPolylineOverlay(
        id: 'path_to_stop', 
        coords: finalPathCoords, 
        color: Colors.blueAccent, 
        width: 6,
      );
      try { _mapController!.addOverlay(path); } catch (e) {}
    }

    // 3. 마커 업데이트 (모든 셔틀장 + 현재 목적지)
    if (mounted) {
      _markers.clear();
      
      // 3-A. 외부 셔틀장 마커 4개 추가
      for (int i = 0; i < EXTERNAL_STOPS.length; i++) {
          _markers.add(
            NMarker(
              id: 'external_stop_$i',
              position: EXTERNAL_STOPS[i],
              caption: NOverlayCaption(text: _stationNames[i]),
            )
          );
      }
      
      // 3-B. 학교 내부 셔틀장 마커 추가
      _markers.add(
        NMarker(
          id: 'school_stop_main',
          position: SCHOOL_SHUTTLE_STOP,
          caption: const NOverlayCaption(text: '학교 셔틀장'),
        )
      );
      
      // ⭐️ 3-C. 현재 위치 마커 추가 (새로 추가)
      if (_currentUserPosition != null) {
          _markers.add(
            NMarker(
              id: 'current_user_pos',
              position: _currentUserPosition!,
              caption: const NOverlayCaption(text: '현재 위치'),
            )
          );
      }

      // 3-D. 현재 안내 중인 최종 목적지 마커를 추가 (강조)
      String destinationName = _isUserInsideSchool() 
                                ? '학교 셔틀장 (목적지)' 
                                : _stationNames[_selectedStationIndex] + ' (선택된 승차장)';
                                  
      _markers.add(
        NMarker(
          id: 'destination_active', 
          position: finalDestination, 
          caption: NOverlayCaption(text: destinationName, color: Colors.red), 
        )
      );
      
      _mapController!.addOverlayAll(_markers);

      // 4. UI 업데이트
      setState(() {
        _walkingDistance = actualDist > 1000 ? "${(actualDist/1000).toStringAsFixed(1)} km" : "${actualDist.toStringAsFixed(0)} m";
        _walkingTime = "$walkMin 분";
      });
    }
  }

  // ⭐️ [수정] 학교 외부일 때 역 출발 시간표를 조회하여 UI 업데이트
  Future<void> _fetchBusData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final DateTime now = DateTime.now();
      String formattedTime;
      int diffMinutes;
      
      final String stationNameKey = _stationNames[_selectedStationIndex];
      
      if (_isUserInsideSchool()) {
        // ⭐️ 학교 내부 모드: 기존 임시 로직 유지 (캠퍼스 -> 역)
        int nextMinute = (now.minute ~/ 15 + 1) * 15;
        DateTime nextDeparture = DateTime(now.year, now.month, now.day, now.hour, 0).add(Duration(minutes: nextMinute));
        
        diffMinutes = nextDeparture.difference(now).inMinutes;
        formattedTime = "${nextDeparture.hour.toString().padLeft(2, '0')}:${nextDeparture.minute.toString().padLeft(2, '0')}";
      
      } else {
        // ⭐️ 학교 외부 모드: 하드코딩된 역 -> 캠퍼스 시간표 조회
        final String nextDepTime = _getStationDepartureTime(stationNameKey);

        if (nextDepTime == "운행 종료" || nextDepTime == "시간표 없음") {
            formattedTime = "운행 종료";
            diffMinutes = 0;
        } else {
            final parts = nextDepTime.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            
            DateTime nextDeparture = DateTime(now.year, now.month, now.day, hour, minute);
            
            if (nextDeparture.isBefore(now.subtract(const Duration(minutes: 1)))) {
                // 이미 지난 시간이라면 (운행 종료 또는 다음 날 첫차)
                formattedTime = nextDepTime; 
                diffMinutes = 0; 
            } else {
                diffMinutes = nextDeparture.difference(now).inMinutes.ceil();
                formattedTime = nextDepTime;
            }
        }
      }
      
      if (mounted) {
        setState(() {
          _nextDepartureTime = formattedTime;
          _timeRemaining = "$diffMinutes분";
          _isLoading = false;
        });
      }

      if (_mapController != null && _currentUserPosition != null) {
        _updatePathToStop();
      }

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onStationSelected(int index) {
    setState(() {
      _selectedStationIndex = index;
      _isLoading = true;
      _isTooFar = false; 
    });
    
    // ⭐️ [변경] 사용자가 학교 밖에 있을 때, 선택된 셔틀장으로 카메라 이동
    if (_mapController != null && _currentUserPosition != null && !_isUserInsideSchool()) {
        final newTargetStop = EXTERNAL_STOPS[index];
        _mapController!.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
                target: newTargetStop,
                zoom: 15.5,
            )
        );
    }
    
    _fetchBusData();
  }

  @override
  Widget build(BuildContext context) {
    // ⭐️ UI 문구 결정 로직 (이 로직은 정확히 작동함)
    final String selectedStationName = _stationNames[_selectedStationIndex];
    final String directionText = _isUserInsideSchool() ? 
                                  '${selectedStationName}행' : 
                                  '아산캠퍼스행';
                                  
    return Column(
      children: [
        _buildHeader(),
        _buildStationSelector(),
        Expanded(
          child: Stack(
            children: [
              // 500m 이내일 때만 지도 표시
              if (!_isTooFar) 
                NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: _initialCameraPosition,
                    indoorEnable: false,
                    locationButtonEnable: true,
                    mapType: NMapType.basic,
                    symbolScale: 0.8,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;
                    
                    // ⭐️ MapReady 시 카메라를 현재 위치 또는 선택된 역으로 이동
                    if (_currentUserPosition != null) {
                        final targetStop = !_isUserInsideSchool() ? EXTERNAL_STOPS[_selectedStationIndex] : SCHOOL_SHUTTLE_STOP;
                        controller.updateCamera(
                            NCameraUpdate.scrollAndZoomTo(
                                target: targetStop,
                                zoom: 15.5, 
                            )
                        );
                    }
                    
                    // 맵 준비 완료 후, 경로 업데이트를 강제 실행
                    if (_currentUserPosition != null) {
                        _updatePathToStop();
                    }
                    
                    _fetchBusData();
                  },
                ),
              
              // 500m 초과일 때 경고 메시지 표시
              if (_isTooFar)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      '선택하신 셔틀장 위치가 현재 위치에서 500m 밖에 있어\n경로 안내를 할 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
                    ),
                  ),
                ),
              
              // 상단 정보 카드 (directionText)
              Positioned(top: 16, right: 16, left: 16, child: _buildTopInfoCard(directionText)),
              
              // 최신 공지 카드 (상단 정보 카드 아래 - top: 90)
              if (_latestNotice != null)
                Positioned(
                  top: 90,
                  right: 16,
                  left: 16,
                  child: _buildNoticeCard(),
                ),
              
              // 하단 정보 카드 (도보 정보)
              Positioned(bottom: 20, left: 20, right: 20, child: _buildBottomInfoCard()),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI 위젯 구현 ---
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            const Icon(Icons.directions_bus_filled, size: 30, color: Color(0xFF1565C0)),
            const SizedBox(width: 10),
            const Text('등하교 셔틀', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.announcement, size: 28, color: Colors.grey),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusNoticesScreen(),
                  ),
                );
              },
              tooltip: '셔틀 공지',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _stationNames.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedStationIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _stationNames[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1565C0),
              backgroundColor: Colors.grey[200],
              onSelected: (_) => _onStationSelected(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopInfoCard(String directionText) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(directionText, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(_nextDepartureTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
            child: Text('$_timeRemaining 남음', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 최신 공지 카드
  Widget _buildNoticeCard() {
    if (_latestNotice == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShuttleNoticeDetailScreen(
              noticeId: _latestNotice!.id,
              initialTitle: _latestNotice!.title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.announcement, color: Colors.orange[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _latestNotice!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _latestNotice!.formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  // 하단 카드: 승강장까지 도보 정보
  Widget _buildBottomInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isUserInsideSchool() ? "승강장까지 거리" : "셔틀장까지 거리", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_walkingDistance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1565C0))),
          ]),
          Container(height: 30, width: 1, color: Colors.grey[300]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("도보 예상 시간", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_walkingTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
          ]),
        ],
      ),
    );
  }
}