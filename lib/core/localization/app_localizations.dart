/// 앱 다국어 지원 클래스
/// 언어 설정에 따라 한국어/영어 텍스트 제공
class AppLocalizations {
  final bool isKorean;

  AppLocalizations(this.isKorean);

  // 메인 화면
  String get appTitle => isKorean ? '선문대 셔틀버스' : 'Sunmoon Shuttle';
  String get announcement => isKorean ? '공지사항' : 'Announcement';
  String get loading => isKorean ? '로딩 중...' : 'Loading...';

  // 설정 화면
  String get settingsTitle => isKorean ? '설정 페이지' : 'Settings';
  String get crowdAnimation => isKorean ? '혼잡도 애니메이션' : 'Crowd Animation';
  String get language => isKorean ? '언어' : 'Language';
  // 현재 언어 표시 (한국어일 때 "한국어", 영어일 때 "English")
  String get currentLanguageDisplay => isKorean ? '한국어' : 'English';
  String get logout => isKorean ? '로그아웃' : 'Logout';
  String get logoutConfirm => isKorean ? '정말 로그아웃 하시겠습니까?' : 'Are you sure you want to logout?';
  String get cancel => isKorean ? '취소' : 'Cancel';
  String get crowdAnimationOn => isKorean ? '혼잡도 애니메이션이 켜졌습니다.' : 'Crowd animation is turned on.';
  String get crowdAnimationOff => isKorean ? '혼잡도 애니메이션이 꺼졌습니다.' : 'Crowd animation is turned off.';
  String get languageChangedKo => isKorean ? '언어가 한국어로 변경되었습니다.' : 'Language changed to Korean.';
  String get languageChangedEn => isKorean ? 'Language changed to English.' : 'Language changed to English.';
  String get settingUpdateFailed => isKorean ? '설정 업데이트에 실패했습니다.' : 'Failed to update settings.';
  String get settingUpdateError => isKorean ? '설정 업데이트 중 오류가 발생했습니다.' : 'An error occurred while updating settings.';

  // 로그인 화면
  String get userId => isKorean ? '아이디' : 'User ID';
  String get password => isKorean ? '비밀번호' : 'Password';
  String get login => isKorean ? '로그인' : 'Login';
  String get processing => isKorean ? '처리 중...' : 'Processing...';
  String get register => isKorean ? '회원가입' : 'Register';
  String get loginFailed => isKorean ? '로그인 실패' : 'Login failed';

  // 포털 화면
  String get portalTitle => isKorean ? '선문대학교 포털' : 'Sunmoon University Portal';
  String get timetableTitle => isKorean ? '학기 시간표' : 'Semester Timetable';
  String get portalLoginSuccess => isKorean ? '포털 로그인 성공' : 'Portal login successful';
  String get portalSessionRefresh => isKorean ? '포털 세션을 새로고침합니다. 다시 로그인해주세요.' : 'Refreshing portal session. Please login again.';
  String get pageLoadError => isKorean ? '페이지 로드 오류' : 'Page load error';
  String get cookieCheckError => isKorean ? '쿠키 확인 중 오류가 발생했습니다' : 'An error occurred while checking cookies';
  String get retry => isKorean ? '다시 시도' : 'Retry';

  // 포털 계정 연동
  String get portalLinkTitle => isKorean ? '포털 계정 연동' : 'Portal Account Link';
  String get portalLinkDescription => isKorean 
      ? '개인 시간표 연동을 위해 학교 포털 계정 정보를 입력해주세요. 정보는 암호화되어 안전하게 저장됩니다.'
      : 'Please enter your school portal account information to link your personal timetable. Your information will be encrypted and stored securely.';
  String get portalId => isKorean ? '포털 ID' : 'Portal ID';
  String get portalIdHint => isKorean ? '학번을 입력하세요' : 'Enter your student ID';
  String get portalIdRequired => isKorean ? '포털 ID를 입력해주세요' : 'Please enter your portal ID';
  String get portalPassword => isKorean ? '포털 비밀번호' : 'Portal Password';
  String get portalPasswordHint => isKorean ? '포털 비밀번호를 입력하세요' : 'Enter your portal password';
  String get portalPasswordRequired => isKorean ? '포털 비밀번호를 입력해주세요' : 'Please enter your portal password';
  String get save => isKorean ? '저장' : 'Save';
  String get portalAccountSaved => isKorean ? '포털 계정이 저장되었습니다' : 'Portal account saved successfully';
  String get portalOpenedInBrowser => isKorean ? '포털이 외부 브라우저에서 열렸습니다' : 'Portal opened in external browser';
  String get portalCookieExpired => isKorean ? '포털 세션이 만료되었습니다. 다시 로그인해주세요.' : 'Portal session has expired. Please login again.';
  String get portalSessionExpired => isKorean ? '세션 만료' : 'Session Expired';
  String get refreshSession => isKorean ? '세션 새로고침' : 'Refresh Session';

  // 공지사항
  String get noticeListTitle => isKorean ? '공지사항' : 'Notices';
  String get noNotices => isKorean ? '공지사항이 없습니다.' : 'No notices available.';
  String get noticeDetailTitle => isKorean ? '공지사항 상세' : 'Notice Detail';
  String get noticeNotFound => isKorean ? '공지사항을 찾을 수 없습니다.' : 'Notice not found.';
  String get noContent => isKorean ? '내용이 없습니다.' : 'No content available.';

  // 기타
  String get on => isKorean ? 'ON' : 'ON';
  String get off => isKorean ? 'OFF' : 'OFF';
}

