# CORS 에러 해결 방법

## ⚠️ 현재 발생 중인 문제

**에러 메시지:**
```
Method PATCH is not allowed by Access-Control-Allow-Methods in preflight response.
```

**원인:**
- Flutter Web에서 `PATCH /api/users/me` 요청 시 브라우저가 먼저 `OPTIONS` preflight 요청을 보냄
- 서버의 `Access-Control-Allow-Methods` 헤더에 `PATCH`가 포함되어 있지 않음
- 브라우저가 실제 PATCH 요청을 보내기 전에 차단

**영향:**
- 언어 설정 변경 (`PATCH /api/users/me`) 실패
- 혼잡도 애니메이션 설정 변경 (`PATCH /api/users/me`) 실패

## 문제 상황
Flutter 웹 앱(`http://localhost:52745`)에서 서버(`http://124.61.202.9:8080`)로 PATCH 요청 시 CORS 정책으로 인해 차단됨

## 🔧 해결 방법

### ✅ 방법 1: 서버 측에서 CORS 설정 (필수 - 백엔드 수정 필요)

**⚠️ 중요: PATCH 메서드를 반드시 추가해야 합니다!**

서버 코드에 CORS 헤더를 추가해야 합니다.

#### Spring Boot (Java)의 경우:

**방법 A: @CrossOrigin 어노테이션 사용**
```java
@RestController
@RequestMapping("/api/users")
@CrossOrigin(
    origins = "*", // 개발용: 모든 origin 허용
    // 프로덕션: origins = "https://yourdomain.com"
    methods = {RequestMethod.GET, RequestMethod.POST, RequestMethod.PUT, 
               RequestMethod.PATCH, RequestMethod.DELETE, RequestMethod.OPTIONS} // PATCH 추가 필수!
)
public class UserController {
    // PATCH /api/users/me 엔드포인트
    @PatchMapping("/me")
    public ResponseEntity<?> updateMe(@RequestBody Map<String, Object> body) {
        // ...
    }
}
```

**방법 B: 전역 CORS 설정 (권장)**
```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("*") // 개발용: 모든 origin 허용
            // 프로덕션에서는 특정 도메인만: .allowedOrigins("https://yourdomain.com")
            .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS") // PATCH 추가
            .allowedHeaders("*")
            .allowCredentials(false); // true로 설정하면 allowedOrigins에 "*" 사용 불가
    }
}
```

**방법 C: Filter 사용**
```java
@Component
public class CorsFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        HttpServletResponse response = (HttpServletResponse) res;
        HttpServletRequest request = (HttpServletRequest) req;
        
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS"); // PATCH 추가
        response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
        response.setHeader("Access-Control-Max-Age", "3600");
        
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            response.setStatus(HttpServletResponse.SC_OK);
        } else {
            chain.doFilter(req, res);
        }
    }
}
```

#### Node.js/Express의 경우:
```javascript
const express = require('express');
const cors = require('cors');
const app = express();

// 모든 origin 허용 (개발용)
app.use(cors());

// 또는 특정 origin만 허용
app.use(cors({
  origin: 'http://localhost:57493',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'], // PATCH 추가
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### ⚠️ 방법 2: 개발 환경 임시 해결 (권장하지 않음)

**Chrome 확장 프로그램 사용 (개발용만)**
1. Chrome 웹스토어에서 "CORS Unblock" 또는 "Allow CORS" 확장 프로그램 설치
2. 개발 중에만 활성화
3. ⚠️ 프로덕션에서는 사용하지 마세요!

### 📝 확인 사항

서버 설정 후 다음을 확인하세요:

1. **OPTIONS 요청 처리**: 브라우저는 먼저 OPTIONS 요청(preflight)을 보냅니다. 서버가 이를 처리해야 합니다.

2. **헤더 확인**: 서버 응답에 다음 헤더가 포함되어야 합니다:
   ```
   Access-Control-Allow-Origin: *
   Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
   Access-Control-Allow-Headers: Content-Type, Authorization
   ```
   
   ⚠️ **중요**: PATCH 메서드가 포함되어야 합니다. 현재 서버 설정에 PATCH가 누락되어 있어 오류가 발생합니다.

3. **브라우저 개발자 도구 확인**:
   - Network 탭에서 OPTIONS 요청이 성공하는지 확인
   - Response Headers에 CORS 헤더가 있는지 확인

## 현재 상황

- **클라이언트**: Flutter 웹 앱 (`http://localhost:57493`)
- **서버**: `http://124.61.202.9:8080`
- **문제**: 서버에서 CORS 헤더를 반환하지 않아 요청이 차단됨

## 🔍 확인 방법

### 1. OPTIONS 요청 테스트 (curl)
```bash
curl -i -X OPTIONS http://124.61.202.9:8080/api/users/me \
  -H "Origin: http://localhost:52745" \
  -H "Access-Control-Request-Method: PATCH" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization"
```

**예상 응답 헤더 (수정 후):**
```
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: http://localhost:52745
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS  ← PATCH 포함 확인!
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 3600
```

### 2. 브라우저 개발자 도구 확인
1. Network 탭 열기
2. 언어 설정 변경 시도
3. `OPTIONS /api/users/me` 요청 확인
4. Response Headers에서 `Access-Control-Allow-Methods` 확인
5. `PATCH`가 포함되어 있는지 확인

## 📋 다음 단계

1. ✅ 백엔드 개발자에게 CORS 설정 수정 요청 (PATCH 메서드 추가)
2. ✅ 서버 재시작
3. ✅ curl로 OPTIONS 요청 테스트
4. ✅ 브라우저 개발자 도구에서 Network 탭 확인
5. ✅ Flutter 앱에서 언어 설정 변경 테스트

## ⚡ 임시 해결책 (프론트엔드)

현재 프론트엔드에서는 CORS 오류 발생 시:
- ✅ 로컬에만 설정 저장 (SharedPreferences)
- ✅ 사용자에게 명확한 안내 메시지 표시
- ✅ 서버 설정 수정 후 자동 동기화 가능

**하지만 근본적인 해결은 백엔드 CORS 설정 수정이 필요합니다!**

