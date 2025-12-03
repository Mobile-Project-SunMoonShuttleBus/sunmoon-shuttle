# 폰트 파일 안내

이 폴더에 다음 Noto Sans KR 폰트 파일들을 추가해주세요:

- `NotoSansKR-Regular.otf` (또는 `.ttf`)
- `NotoSansKR-Bold.otf` (또는 `.ttf`)

## 다운로드 방법

1. **Google Fonts에서 다운로드:**
   - https://fonts.google.com/noto/specimen/Noto+Sans+KR
   - "Download family" 버튼 클릭
   - 압축 해제 후 위 파일들을 이 폴더에 복사

2. **GitHub에서 다운로드:**
   - https://github.com/google/fonts/tree/main/ofl/notosanskr
   - `NotoSansKR-Regular.otf`와 `NotoSansKR-Bold.otf` 파일 다운로드

## 주의사항

- 파일 확장자가 `.ttf`인 경우, `pubspec.yaml`의 경로도 `.ttf`로 수정해야 합니다.
- 폰트 파일 추가 후 `flutter pub get` 실행 필수!
