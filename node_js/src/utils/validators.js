import { z } from 'zod';

const userIdSchema = z.string().regex(/^[A-Za-z0-9]{4,20}$/, 'userId must be 4-20 alphanumeric characters');
const passwordSchema = z
  .string()
  .min(8, 'password must be at least 8 characters')
  .max(64, 'password must be at most 64 characters')
  .regex(/^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,64}$/, 'password must include letters and numbers');

export function validateRegisterPayload(body) {
  const schema = z
    .object({
      userId: userIdSchema,
      password: passwordSchema,
      passwordConfirm: z.string(),
      displayName: z.string().trim().min(1).optional(),
      email: z.string().email().optional(),
    })
    .refine((data) => data.password === data.passwordConfirm, {
      message: 'passwordConfirm must match password',
      path: ['passwordConfirm'],
    });

  return schema.safeParse(body);
}

export function validateLoginPayload(body) {
  const schema = z.object({
    userId: userIdSchema,
    password: z.string().min(1),
  });
  return schema.safeParse(body);
}

