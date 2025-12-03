// lib/core/localization/app_localizations.dart

class AppLocalizations {
  final bool isKorean;

  AppLocalizations(this.isKorean);

  // --- 공통 (Common) ---
  String get appTitle => isKorean ? '선문대 셔틀버스' : 'Sunmoon Shuttle';
  String get confirm => isKorean ? '확인' : 'Confirm';
  String get cancel => isKorean ? '취소' : 'Cancel';
  String get retry => isKorean ? '재시도' : 'Retry'; // [추가됨]
  String get save => isKorean ? '저장' : 'Save'; // [추가됨]
  String get processing => isKorean ? '처리 중...' : 'Processing...'; // [추가됨]

  // --- 메인 탭바 (TabBar) ---
  String get tabMain => isKorean ? '메인화면' : 'Home';
  String get tabLocation => isKorean ? '위치' : 'Location';
  String get tabShuttle => isKorean ? '셔틀시간표' : 'Bus Time';
  String get tabSchool => isKorean ? '학기시간표' : 'School Time';
  String get tabSettings => isKorean ? '설정' : 'Settings';

  // --- 설정 화면 (Settings) ---
  String get settingsTitle => isKorean ? '설정' : 'Settings';
  String get language => isKorean ? '언어 설정' : 'Language';
  String get languageOption => isKorean ? '한국어' : 'English';
  String get account => isKorean ? '계정' : 'Account';
  String get logout => isKorean ? '로그아웃' : 'Logout';
  String get logoutConfirm => isKorean ? '정말 로그아웃 하시겠습니까?' : 'Are you sure you want to logout?';
  String get appInfo => isKorean ? '앱 정보' : 'App Info';
  String get version => isKorean ? '버전 정보' : 'Version';
  String get license => isKorean ? '오픈소스 라이선스' : 'Open Source License';

  // --- 로그인/회원가입 (Auth) ---
  String get login => isKorean ? '로그인' : 'Login';
  String get register => isKorean ? '회원가입' : 'Sign Up';
  String get loginFailed => isKorean ? '로그인에 실패했습니다.' : 'Login failed.';
  String get userId => isKorean ? '아이디' : 'ID';
  String get password => isKorean ? '비밀번호' : 'Password';
  
  // --- 공지사항 (Notice) - [여기서 오류 발생했음] ---
  String get noticeListTitle => isKorean ? '공지사항' : 'Notices'; // [추가됨]
  String get noticeDetailTitle => isKorean ? '공지 상세' : 'Notice Detail'; // [추가됨]
  String get noticeNotFound => isKorean ? '공지를 찾을 수 없습니다.' : 'Notice not found.'; // [추가됨]
  String get noContent => isKorean ? '내용이 없습니다.' : 'No content available.'; // [추가됨]
  String get noNotices => isKorean ? '공지사항이 없습니다.' : 'No notices.'; // [추가됨]

  // --- 포털 연동 (Portal Link) ---
  String get portalLinkTitle => isKorean ? '포털 계정 연동' : 'Link Portal Account';
  String get portalLinkDescription => isKorean 
      ? '포털 아이디와 비밀번호를 저장하면 시간표를 자동으로 가져옵니다.' 
      : 'Save your portal ID and password to automatically fetch your timetable.';
  String get portalId => isKorean ? '포털 학번/ID' : 'Portal ID';
  String get portalIdHint => isKorean ? '학번을 입력하세요' : 'Enter Student ID';
  String get portalIdRequired => isKorean ? '학번을 입력해주세요.' : 'Student ID is required.';
  String get portalPassword => isKorean ? '포털 비밀번호' : 'Portal Password';
  String get portalPasswordHint => isKorean ? '비밀번호를 입력하세요' : 'Enter Password';
  String get portalPasswordRequired => isKorean ? '비밀번호를 입력해주세요.' : 'Password is required.';
  String get portalAccountSaved => isKorean ? '포털 계정이 저장되었습니다.' : 'Portal account saved.';
  
  // --- 학기 시간표 (Timetable) ---
  String get timetableTitle => isKorean ? '학기 시간표' : 'School Timetable';
  String get fetchingTimetable => isKorean ? '시간표를 가져오는 중입니다. 잠시만 기다려주세요...' : 'Fetching timetable. Please wait...';
  String get timetableFetchFailed => isKorean ? '시간표 데이터를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.' : 'Failed to fetch timetable data. Please try again later.';
  String get timetableFetchTimeout => isKorean ? '시간표를 가져오는데 시간이 오래 걸리고 있습니다. 잠시 후 새로고침을 해주세요.' : 'Timetable fetching is taking too long. Please refresh later.';
  String get noTimetableData => isKorean ? '시간표 데이터가 없습니다. 포털 연동을 해주세요.' : 'No timetable data. Please link your portal account.';
  String get timetableLoadFailed => isKorean ? '시간표를 불러오는데 실패했습니다' : 'Failed to load timetable';
  String get portalLoginSuccess => isKorean ? '포털 로그인 성공! 계정 정보를 저장해주세요.' : 'Portal login successful! Please save your account information.';
  String get accountSavedFetching => isKorean ? '서버에 저장되었습니다. 시간표를 가져옵니다.' : 'Saved to server. Fetching timetable.';
  String get saveFailed => isKorean ? '저장 실패' : 'Save failed';
  String get portalAccountSave => isKorean ? '포털 계정 저장' : 'Save Portal Account';
  String get portalAccountSaveDescription => isKorean ? '학번과 비밀번호를 입력하면\n자동으로 시간표를 가져옵니다.' : 'Enter your student ID and password\nto automatically fetch your timetable.';
  String get refresh => isKorean ? '새로고침' : 'Refresh';
  String get portalLink => isKorean ? '포털 연동' : 'Link Portal';
  String get updating => isKorean ? '업데이트' : 'Updating';
  String get crawling => isKorean ? '크롤링 중...' : 'Crawling...';
  String get noData => isKorean ? '데이터 없음' : 'No Data';
  String get loading => isKorean ? '로딩 중...' : 'Loading...';
  String get subjectsCount => isKorean ? '과목' : 'Subjects';
  String get fetchingTimetableMessage => isKorean ? '시간표를 가져오는 중입니다' : 'Fetching timetable';
  
  // 요일 (Days)
  String get monday => isKorean ? '월' : 'Mon';
  String get tuesday => isKorean ? '화' : 'Tue';
  String get wednesday => isKorean ? '수' : 'Wed';
  String get thursday => isKorean ? '목' : 'Thu';
  String get friday => isKorean ? '금' : 'Fri';
  
  // 빈 상태 메시지
  String get noTimetableMessage => isKorean ? '시간표가 없습니다.\n포털 연동을 해주세요.' : 'No timetable.\nPlease link your portal account.';
}