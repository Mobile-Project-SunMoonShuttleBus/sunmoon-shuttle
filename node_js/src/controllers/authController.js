import { registerUser, loginUser } from '../services/authService.js';
import { validateRegisterPayload, validateLoginPayload } from '../utils/validators.js';

export async function register(req, res) {
  // 1. 요청 본문 Validate → 필수값/형식 위반 시 400 반환
  const parseResult = validateRegisterPayload(req.body);
  if (!parseResult.success) {
    return res.status(400).json({
      message: '회원가입 실패',
      error: 'VALIDATION_ERROR',
    });
  }

  try {
    const { userId, password, displayName, email } = parseResult.data;
    // 2. userId 중복 검사 (UNIQUE)
    // 3. password 해시(bcrypt, 최소 10 saltRounds)
    // 4. DB 저장(생성 시각 createdAt 포함)
    const result = await registerUser({ userId, password, displayName, email });
    
    // 5. 성공/실패 결과 반환
    return res.status(201).json({
      message: '회원가입이 완료되었습니다.',
      userId: result.userId,
      createdAt: result.createdAt,
    });
  } catch (err) {
    if (err.code === 'USER_ID_TAKEN') {
      return res.status(400).json({
        message: '회원가입 실패',
        error: 'USER_ID_TAKEN',
      });
    }
    console.error('register error', err);
    return res.status(500).json({
      message: '회원가입 실패',
      error: 'INTERNAL_ERROR',
    });
  }
}

export async function login(req, res) {
  const parseResult = validateLoginPayload(req.body);
  if (!parseResult.success) {
    return res.status(400).json({
      message: '로그인 실패',
      error: 'VALIDATION_ERROR',
      details: parseResult.error.flatten(),
    });
  }

  try {
    const { userId, password } = parseResult.data;
    const result = await loginUser({ userId, password });
    return res.status(200).json(result);
  } catch (err) {
    if (err.code === 'INVALID_CREDENTIALS') {
      return res.status(401).json({
        message: '로그인 실패',
      });
    }
    console.error('login error', err);
    return res.status(500).json({
      message: '로그인 실패',
      error: 'INTERNAL_ERROR',
    });
  }
}

