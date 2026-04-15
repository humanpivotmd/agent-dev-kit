// Fixture: security-critical file. Should trigger SECURITY_KEYWORDS heuristic
// in impact-analyzer.mjs (path contains 'auth') regardless of fan-in.
//
// Not imported by any consumer — tests that security heuristic triggers
// independently of caller count.

export function verifyPassword(password: string, hash: string): boolean {
  return password.length > 0 && hash.length > 0;
}

export const SESSION_SECRET = 'placeholder';

export interface AuthToken {
  sub: string;
  exp: number;
}
