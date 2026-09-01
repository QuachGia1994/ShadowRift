import { applyCommand, createInitialState, parseCommand, type GameState } from "./domain";

interface Env {
  GAME_SESSIONS: DurableObjectNamespace<GameSession>;
}

interface StoredSession {
  tokenHash: string;
  game: GameState;
}

const MAX_BODY_BYTES = 4096;
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/v1/health") {
      return json({ ok: true, service: "shadowrift-authority" });
    }
    if (request.method === "POST" && url.pathname === "/v1/sessions") {
      const sessionId = crypto.randomUUID();
      const token = randomToken();
      const stub = env.GAME_SESSIONS.get(env.GAME_SESSIONS.idFromName(sessionId));
      const response = await stub.fetch("https://session/internal/create", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ tokenHash: await sha256(token) }),
      });
      if (!response.ok) return json({ ok: false, code: "session_create_failed" }, 503);
      const created = (await response.json()) as { state: GameState };
      return json({ ok: true, sessionId, token, state: created.state }, 201);
    }
    const snapshotMatch = url.pathname.match(/^\/v1\/sessions\/([0-9a-f-]{36})$/i);
    const commandMatch = url.pathname.match(/^\/v1\/sessions\/([0-9a-f-]{36})\/commands$/i);
    if (!snapshotMatch && !commandMatch) return json({ ok: false, code: "not_found" }, 404);
    const sessionId = (snapshotMatch ?? commandMatch)![1];
    const authorization = request.headers.get("authorization") ?? "";
    const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
    if (token.length < 32 || token.length > 256) return json({ ok: false, code: "unauthorized" }, 401);
    const stub = env.GAME_SESSIONS.get(env.GAME_SESSIONS.idFromName(sessionId));
    if (request.method === "GET" && snapshotMatch) {
      return stub.fetch("https://session/internal/snapshot", {
        method: "GET",
        headers: { "x-token-hash": await sha256(token) },
      });
    }
    if (request.method !== "POST" || !commandMatch) return json({ ok: false, code: "not_found" }, 404);
    if (request.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase() !== "application/json") {
      return json({ ok: false, code: "json_required" }, 415);
    }
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (declaredLength > MAX_BODY_BYTES) return json({ ok: false, code: "body_too_large" }, 413);
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json({ ok: false, code: "body_too_large" }, 413);
    let command: unknown;
    try { command = JSON.parse(raw); } catch { return json({ ok: false, code: "invalid_json" }, 400); }
    return stub.fetch("https://session/internal/command", {
      method: "POST",
      headers: { "content-type": "application/json", "x-token-hash": await sha256(token) },
      body: JSON.stringify(command),
    });
  },
} satisfies ExportedHandler<Env>;

export class GameSession extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/internal/create") {
      const existing = await this.ctx.storage.get<StoredSession>("session");
      if (existing) return json({ ok: false, code: "already_exists" }, 409);
      const body = (await request.json()) as { tokenHash?: unknown };
      if (typeof body.tokenHash !== "string" || body.tokenHash.length !== 64) return json({ ok: false, code: "invalid_token_hash" }, 400);
      const session: StoredSession = { tokenHash: body.tokenHash, game: createInitialState(Date.now()) };
      await this.ctx.storage.put("session", session);
      return json({ ok: true, state: session.game }, 201);
    }
    if (request.method === "GET" && url.pathname === "/internal/snapshot") {
      const session = await this.ctx.storage.get<StoredSession>("session");
      if (!session) return json({ ok: false, code: "unknown_session" }, 404);
      if (!constantTimeEqual(request.headers.get("x-token-hash") ?? "", session.tokenHash)) return json({ ok: false, code: "unauthorized" }, 401);
      return json({ ok: true, state: session.game });
    }
    if (request.method !== "POST" || url.pathname !== "/internal/command") return json({ ok: false, code: "not_found" }, 404);
    const session = await this.ctx.storage.get<StoredSession>("session");
    if (!session) return json({ ok: false, code: "unknown_session" }, 404);
    if (!constantTimeEqual(request.headers.get("x-token-hash") ?? "", session.tokenHash)) return json({ ok: false, code: "unauthorized" }, 401);
    let raw: unknown;
    try { raw = await request.json(); } catch { return json({ ok: false, code: "invalid_json" }, 400); }
    const command = parseCommand(raw);
    if (!command) return json({ ok: false, code: "invalid_command", state: session.game }, 400);
    const result = applyCommand(session.game, command, Date.now());
    if (result.ok) {
      session.game = result.state;
      await this.ctx.storage.put("session", session);
    }
    return json(result, result.ok ? 200 : 409);
  }
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}
