import bcrypt from 'bcrypt';
import { createUser, findByUserId } from '../models/userAccount.js';
import { createAccessToken } from '../utils/jwtHandler.js';
import db from '../db/index.js';

const SALT_ROUNDS = 12; // 요구사항: 최소 10 saltRounds

export async function registerUser({ userId, password, displayName, email }) {
  // 1. 비밀번호 해시 (bcrypt, 최소 10 saltRounds) - 비동기 작업이므로 먼저 처리
  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const createdAt = new Date().toISOString();

  // 2. 트랜잭션을 사용하여 중복 검사 및 DB 저장 (경합 조건 방지)
  const transaction = db.transaction((userId, passwordHash, displayName, email, createdAt) => {
    // 중복 검사
    const existing = findByUserId(userId);
    if (existing) {
      const error = new Error('USER_ID_TAKEN');
      error.code = 'USER_ID_TAKEN';
      throw error;
    }

    // DB 저장 (UNIQUE 제약조건으로 이중 보호)
    const user = createUser({ userId, passwordHash, displayName, email, createdAt });
    return {
      userId: user.userId,
      createdAt: user.createdAt,
    };
  });

  try {
    // 트랜잭션 실행
    const result = transaction(userId, passwordHash, displayName, email, createdAt);
    return result;
  } catch (err) {
    if (err.code === 'USER_ID_TAKEN') {
      throw err;
    }
    // UNIQUE 제약조건 위반 시 (SQLite 에러 - 경합 조건 발생)
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || err.message?.includes('UNIQUE constraint')) {
      const error = new Error('USER_ID_TAKEN');
      error.code = 'USER_ID_TAKEN';
      throw error;
    }
    throw err;
  }
}

export async function loginUser({ userId, password }) {
  const existing = findByUserId(userId);
  if (!existing) {
    const error = new Error('INVALID_CREDENTIALS');
    error.code = 'INVALID_CREDENTIALS';
    throw error;
  }

  const match = await bcrypt.compare(password, existing.passwordHash);
  if (!match) {
    const error = new Error('INVALID_CREDENTIALS');
    error.code = 'INVALID_CREDENTIALS';
    throw error;
  }

  const accessToken = createAccessToken({
    sub: existing.id,
    userId: existing.userId,
  });

  return {
    message: '로그인 성공',
    accessToken,
  };
}

