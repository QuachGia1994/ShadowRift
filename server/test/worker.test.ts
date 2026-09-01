import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

const BASE = "https://authority.test";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

type Json = Record<string, unknown>;

interface Reply {
	status: number;
	body: Json & { ok?: boolean; code?: string; state?: Json; events?: unknown[] };
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

async function send(request: Request): Promise<Reply> {
	const response = await exports.default.fetch(request);
	const text = await response.text();
	let body: unknown;
	try {
		body = JSON.parse(text) as unknown;
	} catch {
		body = { raw: text };
	}
	return { status: response.status, body: body as Reply["body"] };
}

function request(path: string, method: string, token: string | null, body: string | null, contentType = "application/json"): Request {
	const headers: Record<string, string> = {};
	if (token !== null) headers["authorization"] = `Bearer ${token}`;
	if (body !== null) headers["content-type"] = contentType;
	return new Request(`${BASE}${path}`, { method, headers, body: body ?? undefined });
}

function commandRequest(sessionId: string, token: string, payload: unknown): Request {
	return request(`/v1/sessions/${sessionId}/commands`, "POST", token, JSON.stringify(payload));
}

async function createSession(): Promise<{ sessionId: string; token: string; state: Json }> {
	const reply = await send(request("/v1/sessions", "POST", null, null));
	expect(reply.status).toBe(201);
	expect(reply.body.ok).toBe(true);
	const sessionId = String(reply.body.sessionId);
	const token = String(reply.body.token);
	expect(sessionId).toMatch(UUID_PATTERN);
	expect(token.length).toBeGreaterThanOrEqual(32);
	return { sessionId, token, state: reply.body.state as Json };
}

async function snapshot(sessionId: string, token: string): Promise<Reply> {
	return send(request(`/v1/sessions/${sessionId}`, "GET", token, null));
}

async function command(sessionId: string, token: string, seq: number, payload: Record<string, unknown>): Promise<Reply> {
	return send(commandRequest(sessionId, token, { seq, ...payload }));
}

interface SequenceRef {
	value: number;
}

async function sendAccepted(sessionId: string, token: string, seqRef: SequenceRef, payload: Record<string, unknown>): Promise<Reply> {
	for (let attempt = 0; attempt < 20; attempt += 1) {
		const reply = await command(sessionId, token, seqRef.value, payload);
		if (reply.status === 409 && reply.body.code === "rate_limited") {
			await sleep(35);
			continue;
		}
		expect(reply.status).toBe(200);
		expect(reply.body.ok).toBe(true);
		seqRef.value += 1;
		return reply;
	}
	throw new Error("command never passed the rate limiter");
}

async function movePlayerTo(sessionId: string, token: string, seqRef: SequenceRef, targetX: number, direction: -1 | 1, stopOnDeath = false): Promise<Json> {
	for (let attempt = 0; attempt < 120; attempt += 1) {
		const reply = await command(sessionId, token, seqRef.value, { action: "move", direction });
		if (reply.status === 409 && reply.body.code === "rate_limited") {
			await sleep(35);
			continue;
		}
		if (stopOnDeath && reply.status === 409 && reply.body.code === "player_dead") {
			return reply.body.state as Json;
		}
		expect(reply.status).toBe(200);
		seqRef.value += 1;
		const state = reply.body.state as Json;
		const player = state.player as Json;
		const x = Number(player.x);
		if ((direction === 1 && x >= targetX) || (direction === -1 && x <= targetX)) {
			return state;
		}
		await sleep(265);
	}
	throw new Error(`movePlayerTo did not reach ${targetX}`);
}

describe("Shadow Rift authority worker end to end", () => {
	it("answers health checks", async () => {
		const reply = await send(request("/v1/health", "GET", null, null));
		expect(reply.status).toBe(200);
		expect(reply.body).toEqual({ ok: true, service: "shadowrift-authority" });
	});

	it("creates sessions with opaque credentials and canonical initial state", async () => {
		const { sessionId, token, state } = await createSession();
		expect(sessionId).toMatch(UUID_PATTERN);
		expect(token).toMatch(/^[0-9a-f]{64}$/);
		const player = state.player as Json;
		expect(state.revision).toBe(0);
		expect(state.lastSeq).toBe(0);
		expect(player).toEqual({
			x: 180,
			y: 406,
			hp: 140,
			maxHp: 140,
			mana: 100,
			maxMana: 100,
			attack: 24,
			defense: 8,
			level: 1,
			exp: 0,
			expToNext: 100,
			gold: 0,
			weaponId: "rust_blade",
			armorId: "ash_vest",
			lastActionAt: 0,
		});
		const enemies = state.enemies as Array<Json>;
		expect(enemies).toHaveLength(3);
		expect(enemies[0]).toMatchObject({ id: "warden-1", kind: "warden", x: 620, hp: 105, alive: true });
		expect(enemies[1]).toMatchObject({ id: "wraith-1", kind: "wraith", x: 1160, hp: 68, alive: true });
		expect(enemies[2]).toMatchObject({ id: "boss-1", kind: "boss", x: 1970, hp: 420, alive: true });
	});

	it("refuses reads and commands without a valid bearer token", async () => {
		const { sessionId, token } = await createSession();
		const noAuthRead = await send(request(`/v1/sessions/${sessionId}`, "GET", null, null));
		expect(noAuthRead.status).toBe(401);
		const shortTokenRead = await send(request(`/v1/sessions/${sessionId}`, "GET", "a".repeat(31), null));
		expect(shortTokenRead.status).toBe(401);
		const wrongTokenRead = await send(request(`/v1/sessions/${sessionId}`, "GET", "b".repeat(64), null));
		expect(wrongTokenRead.status).toBe(401);
		const noAuthCommand = await send(commandRequest(sessionId, "", { seq: 1, action: "sync" }));
		expect(noAuthCommand.status).toBe(401);
		const wrongTokenCommand = await send(commandRequest(sessionId, "c".repeat(64), { seq: 1, action: "sync" }));
		expect(wrongTokenCommand.status).toBe(401);
		const unknownSession = await send(request(`/v1/sessions/00000000-0000-0000-0000-000000000000`, "GET", token, null));
		expect(unknownSession.status).toBe(404);
		const malformedId = await send(request("/v1/sessions/not-a-uuid", "GET", token, null));
		expect(malformedId.status).toBe(404);
	});

	it("resumes the exact persisted state and lastSeq for the authenticated token", async () => {
		const { sessionId, token } = await createSession();
		await sleep(40);
		const seqRef: SequenceRef = { value: 1 };
		const accepted = await sendAccepted(sessionId, token, seqRef, { action: "sync" });
		const afterCommand = accepted.body.state as Json;
		const resumed = await snapshot(sessionId, token);
		expect(resumed.status).toBe(200);
		expect(resumed.body.ok).toBe(true);
		expect(resumed.body.state).toEqual(afterCommand);
		expect((resumed.body.state as Json).lastSeq).toBe(1);
		const again = await snapshot(sessionId, token);
		expect(again.body.state).toEqual(afterCommand);
	});

	it("rejects client-owned and unknown fields without mutating state", async () => {
		const { sessionId, token } = await createSession();
		const hostile = [
			{ action: "attack", damage: 999999 },
			{ action: "attack", attack: 999 },
			{ action: "attack", defense: 999 },
			{ action: "sync", gold: 999 },
			{ action: "sync", hp: 999 },
			{ action: "move", direction: 1, clientTime: 1234567890 },
			{ action: "attack", targetId: "warden-1" },
			{ action: "equip", slot: "weapon", itemId: "rift_saber", save: { gold: 999 } },
		];
		for (const payload of hostile) {
			const reply = await command(sessionId, token, 1, payload);
			expect(reply.status).toBe(400);
			expect(reply.body.code).toBe("invalid_command");
		}
		const state = (await snapshot(sessionId, token)).body.state as Json;
		expect(state.lastSeq).toBe(0);
		expect(state.revision).toBe(0);
	});

	it("rejects non-JSON and oversized command bodies", async () => {
		const { sessionId, token } = await createSession();
		const wrongType = await send(request(`/v1/sessions/${sessionId}/commands`, "POST", token, "sync", "text/plain"));
		expect(wrongType.status).toBe(415);
		expect(wrongType.body.code).toBe("json_required");
		const notJson = await send(request(`/v1/sessions/${sessionId}/commands`, "POST", token, "not json at all"));
		expect(notJson.status).toBe(400);
		expect(notJson.body.code).toBe("invalid_json");
		const empty = await send(request(`/v1/sessions/${sessionId}/commands`, "POST", token, ""));
		expect(empty.status).toBe(400);
		expect(empty.body.code).toBe("invalid_json");
		const oversized = await send(request(`/v1/sessions/${sessionId}/commands`, "POST", token, JSON.stringify({ seq: 1, action: "sync", padding: "x".repeat(5000) })));
		expect(oversized.status).toBe(413);
		expect(oversized.body.code).toBe("body_too_large");
	});

	it("rejects replayed and gapped sequence numbers without mutating persisted state", async () => {
		const { sessionId, token } = await createSession();
		await sleep(40);
		const first = await command(sessionId, token, 1, { action: "sync" });
		expect(first.status).toBe(200);
		const replay = await command(sessionId, token, 1, { action: "sync" });
		expect(replay.status).toBe(409);
		expect(replay.body.code).toBe("sequence_rejected");
		const gap = await command(sessionId, token, 3, { action: "sync" });
		expect(gap.status).toBe(409);
		expect(gap.body.code).toBe("sequence_rejected");
		const state = (await snapshot(sessionId, token)).body.state as Json;
		expect(state.lastSeq).toBe(1);
		expect(state.revision).toBe(1);
		await sleep(40);
		const next = await command(sessionId, token, 2, { action: "sync" });
		expect(next.status).toBe(200);
		expect((next.body.state as Json).lastSeq).toBe(2);
	});

	it("keeps canonical damage, cooldown, and reward-once server-owned", async () => {
		const { sessionId, token } = await createSession();
		const seqRef: SequenceRef = { value: 1 };
		await movePlayerTo(sessionId, token, seqRef, 560, 1);
		await sleep(40);
		const hit = await command(sessionId, token, seqRef.value, { action: "attack" });
		expect(hit.status).toBe(200);
		seqRef.value += 1;
		let state = hit.body.state as Json;
		let enemies = state.enemies as Array<Json>;
		expect(enemies[0].hp).toBe(85);
		expect(state.player).toMatchObject({ attack: 24 });
		const events = hit.body.events as Array<Json>;
		expect(events[0]).toEqual({ type: "damage", targetId: "warden-1", amount: 20 });
		await sleep(40);
		const cooldown = await command(sessionId, token, seqRef.value, { action: "attack" });
		expect(cooldown.status).toBe(409);
		expect(cooldown.body.code).toBe("cooldown");
		let defeated = false;
		for (let swing = 0; swing < 10 && !defeated; swing += 1) {
			await sleep(280);
			const reply = await command(sessionId, token, seqRef.value, { action: "attack" });
			if (reply.status === 409 && reply.body.code === "rate_limited") continue;
			expect(reply.status).toBe(200);
			seqRef.value += 1;
			state = reply.body.state as Json;
			enemies = state.enemies as Array<Json>;
			defeated = enemies[0].alive === false;
		}
		expect(defeated).toBe(true);
		expect(state.player).toMatchObject({ gold: 7, exp: 24 });
		await sleep(280);
		const extra = await command(sessionId, token, seqRef.value, { action: "attack" });
		expect(extra.status).toBe(409);
		expect(extra.body.code).toBe("no_target");
		expect((extra.body.state as Json).player).toMatchObject({ gold: 7, exp: 24 });
	});

	it("keeps mana, skill costs, and skill range server-owned", async () => {
		const { sessionId, token } = await createSession();
		const seqRef: SequenceRef = { value: 1 };
		await sleep(40);
		const outOfRange = await command(sessionId, token, seqRef.value, { action: "skill", slot: 1 });
		expect(outOfRange.status).toBe(409);
		expect(outOfRange.body.code).toBe("no_target");
		await sleep(40);
		const first = await sendAccepted(sessionId, token, seqRef, { action: "skill", slot: 2 });
		expect((first.body.state as Json).player).toMatchObject({ mana: 66 });
		await sleep(720);
		const second = await sendAccepted(sessionId, token, seqRef, { action: "skill", slot: 2 });
		expect((second.body.state as Json).player).toMatchObject({ mana: 32 });
		await sleep(720);
		const drained = await command(sessionId, token, seqRef.value, { action: "skill", slot: 2 });
		expect(drained.status).toBe(409);
		expect(drained.body.code).toBe("mana");
		expect((drained.body.state as Json).player).toMatchObject({ mana: 32 });
		const enemies = (drained.body.state as Json).enemies as Array<Json>;
		expect(enemies[0].hp).toBe(13);
	});

	it("keeps the equipment allowlist and canonical stats server-owned", async () => {
		const { sessionId, token } = await createSession();
		const seqRef: SequenceRef = { value: 1 };
		await sleep(40);
		const unknownItem = await command(sessionId, token, seqRef.value, { action: "equip", slot: "weapon", itemId: "developer_sword" });
		expect(unknownItem.status).toBe(409);
		expect(unknownItem.body.code).toBe("invalid_item");
		await sleep(40);
		const wrongSlot = await command(sessionId, token, seqRef.value, { action: "equip", slot: "weapon", itemId: "warden_mail" });
		expect(wrongSlot.status).toBe(409);
		expect(wrongSlot.body.code).toBe("invalid_item");
		await sleep(40);
		const weapon = await sendAccepted(sessionId, token, seqRef, { action: "equip", slot: "weapon", itemId: "rift_saber" });
		expect((weapon.body.state as Json).player).toMatchObject({ weaponId: "rift_saber", attack: 32 });
		await sleep(40);
		const armor = await sendAccepted(sessionId, token, seqRef, { action: "equip", slot: "armor", itemId: "warden_mail" });
		expect((armor.body.state as Json).player).toMatchObject({ armorId: "warden_mail", defense: 14 });
	});

	it("clamps movement to server world bounds", async () => {
		const { sessionId, token } = await createSession();
		const seqRef: SequenceRef = { value: 1 };
		const left = await movePlayerTo(sessionId, token, seqRef, 16, -1);
		expect((left.player as Json).x).toBe(16);
		const right = await movePlayerTo(sessionId, token, seqRef, 2384, 1);
		expect((right.player as Json).x).toBe(2384);
	});

	it("keeps player death server-owned while sync stays available", async () => {
		const { sessionId, token } = await createSession();
		const seqRef: SequenceRef = { value: 1 };
		await movePlayerTo(sessionId, token, seqRef, 1970, 1, true);
		let dead = false;
		for (let round = 0; round < 10 && !dead; round += 1) {
			await sleep(1400);
			const beat = await sendAccepted(sessionId, token, seqRef, { action: "sync" });
			const hp = Number((beat.body.state as Json & { player: Json }).player.hp);
			if (hp <= 0) {
				dead = true;
				break;
			}
			await sleep(40);
			const swing = await command(sessionId, token, seqRef.value, { action: "attack" });
			if (swing.status === 409 && swing.body.code === "player_dead") {
				dead = true;
				break;
			}
			if (swing.status === 200) seqRef.value += 1;
		}
		expect(dead).toBe(true);
		const state = (await snapshot(sessionId, token)).body.state as Json;
		expect((state.player as Json).hp).toBe(0);
		await sleep(40);
		const syncWhileDead = await command(sessionId, token, seqRef.value, { action: "sync" });
		expect(syncWhileDead.status).toBe(200);
		await sleep(40);
		const attackWhileDead = await command(sessionId, token, seqRef.value + 1, { action: "attack" });
		expect(attackWhileDead.status).toBe(409);
		expect(attackWhileDead.body.code).toBe("player_dead");
	});
});
