// Anti-pattern fixture: a generate API route that calls Claude but does NOT
// use the required ADK validation helpers, and does NOT use the SSE guard.
// impact-analyzer should flag this with two ADK pattern warnings.
// (Function names intentionally NOT mentioned in comments to avoid
//  false-positive matches on the helper-name regex.)

import { anthropic } from './fake-client';

export async function POST(req: Request) {
  const body = await req.json();
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    messages: [{ role: 'user', content: body.prompt }],
  });
  // directly using response without validation, and no SSE guard
  return new Response(JSON.stringify({ result: response.content[0].text }));
}
