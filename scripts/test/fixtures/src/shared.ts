// Fixture: shared module consumed by consumer-a and consumer-b.
// Also contains a self-reference (FIRST_NAME → NAMES) to test the
// self-reference filter in impact-analyzer.mjs.

export const NAMES = ['foo', 'bar', 'baz'];

export function greet(name: string): string {
  return `Hello, ${name}`;
}

// Self-reference: this export reads another export from the same file.
// The analyzer must NOT count shared.ts as its own caller.
export const FIRST_NAME = NAMES[0];
