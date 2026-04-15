import { greet, NAMES } from './shared';

export function runA(): string {
  return greet(NAMES[0]);
}
