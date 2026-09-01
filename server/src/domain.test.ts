import assert from "node:assert/strict";
import test from "node:test";
import { applyCommand, createInitialState, parseCommand } from "./domain.ts";

test("rejects client-owned combat fields and malformed commands", () => {
  assert.equal(parseCommand({ seq: 1, action: "attack", damage: 999999 }), null);
  assert.equal(parseCommand({ seq: 1, action: "move", direction: 0.5 }), null);
  assert.equal(parseCommand({ seq: 1, action: "equip", slot: "weapon", itemId: "developer_sword", attack: 999 }), null);
});

test("rejects replay and out-of-order sequence numbers", () => {
  const initial = createInitialState(1000);
  const first = applyCommand(initial, { seq: 1, action: "sync" }, 1100);
  assert.equal(first.ok, true);
  assert.equal(applyCommand(first.state, { seq: 1, action: "sync" }, 1200).code, "sequence_rejected");
  assert.equal(applyCommand(first.state, { seq: 3, action: "sync" }, 1200).code, "sequence_rejected");
});

test("caps movement by server elapsed time and world bounds", () => {
  let state = createInitialState(1000);
  const moved = applyCommand(state, { seq: 1, action: "move", direction: 1 }, 5000);
  assert.equal(moved.ok, true);
  assert.equal(moved.state.player.x, 242.5);
  state = { ...moved.state, player: { ...moved.state.player, x: 2380 } };
  assert.equal(applyCommand(state, { seq: 2, action: "move", direction: 1 }, 5250).state.player.x, 2384);
});

test("jump is server-owned, advances vertical position, and rejects airborne repeats", () => {
  const initial = createInitialState(1000);
  const jump = applyCommand(initial, { seq: 1, action: "jump" }, 1100);
  assert.equal(jump.ok, true);
  assert.equal(jump.state.player.y, 406);
  assert.equal(jump.state.player.vy, -520);
  assert.deepEqual(jump.events[0], { type: "jump", x: 180, y: 406 });
  const airborne = applyCommand(jump.state, { seq: 2, action: "move", direction: 0 }, 1180);
  assert.equal(airborne.ok, true);
  assert.ok(airborne.state.player.y < 406);
  assert.ok(airborne.state.player.vy < 0);
  const repeated = applyCommand(airborne.state, { seq: 3, action: "jump" }, 1260);
  assert.equal(repeated.ok, false);
  assert.equal(repeated.code, "jump_airborne");
  assert.equal(repeated.state.lastSeq, 2);
});

test("server selects range-valid target and computes canonical damage", () => {
  const initial = createInitialState(1000);
  const tooFar = applyCommand(initial, { seq: 1, action: "attack" }, 2000);
  assert.equal(tooFar.code, "no_target");
  const inRange = structuredClone(initial);
  inRange.player.x = 600;
  const hit = applyCommand(inRange, { seq: 1, action: "attack" }, 2000);
  assert.equal(hit.ok, true);
  assert.equal(hit.state.enemies[0].hp, 85);
  assert.deepEqual(hit.events[0], { type: "damage", targetId: "warden-1", amount: 20 });
});

test("enforces cooldown and mana without consuming sequence on rejection", () => {
  const initial = createInitialState(1000);
  initial.player.x = 600;
  const first = applyCommand(initial, { seq: 1, action: "skill", slot: 1 }, 2000);
  assert.equal(first.ok, true);
  assert.equal(first.state.player.mana, 78);
  const cooldown = applyCommand(first.state, { seq: 2, action: "attack" }, 2100);
  assert.equal(cooldown.code, "cooldown");
  assert.equal(cooldown.state.lastSeq, 1);
  const noMana = structuredClone(first.state);
  noMana.player.mana = 0;
  assert.equal(applyCommand(noMana, { seq: 2, action: "skill", slot: 2 }, 3000).code, "mana");
});

test("equipment is an allowlist and stats cannot be supplied by client", () => {
  const initial = createInitialState(1000);
  assert.equal(applyCommand(initial, { seq: 1, action: "equip", slot: "weapon", itemId: "developer_sword" }, 1100).code, "invalid_item");
  const valid = applyCommand(initial, { seq: 1, action: "equip", slot: "weapon", itemId: "rift_saber" }, 1100);
  assert.equal(valid.ok, true);
  assert.equal(valid.state.player.weaponId, "rift_saber");
  assert.equal(valid.state.player.attack, 32);
});

test("grants rewards exactly once when server confirms defeat", () => {
  const initial = createInitialState(1000);
  initial.player.x = 600;
  initial.enemies[0].hp = 1;
  const kill = applyCommand(initial, { seq: 1, action: "attack" }, 2000);
  assert.equal(kill.ok, true);
  assert.equal(kill.state.player.gold, 7);
  assert.equal(kill.state.player.exp, 24);
  assert.equal(kill.state.enemies[0].alive, false);
  const next = applyCommand(kill.state, { seq: 2, action: "attack" }, 3000);
  assert.equal(next.code, "no_target");
  assert.equal(next.state.player.gold, 7);
});

test("enemy damage and defense are server-owned", () => {
  const initial = createInitialState(1000);
  initial.player.x = 600;
  const struck = applyCommand(initial, { seq: 1, action: "sync" }, 2000);
  assert.equal(struck.ok, true);
  assert.equal(struck.state.player.defense, 8);
  assert.equal(struck.state.player.hp, 127);
  assert.deepEqual(struck.events[0], { type: "player_damage", sourceId: "warden-1", amount: 13 });
});
