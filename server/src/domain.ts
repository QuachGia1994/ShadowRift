export type EquipmentSlot = "weapon" | "armor";
export type Command =
  | { seq: number; action: "move"; direction: -1 | 0 | 1 }
  | { seq: number; action: "jump" }
  | { seq: number; action: "attack" }
  | { seq: number; action: "skill"; slot: 1 | 2 }
  | { seq: number; action: "equip"; slot: EquipmentSlot; itemId: string }
  | { seq: number; action: "sync" };

export type EnemyKind = "warden" | "wraith" | "boss";

export interface EnemyState {
  id: string;
  kind: EnemyKind;
  x: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  lastAttackAt: number;
}

export interface GameState {
  revision: number;
  lastSeq: number;
  updatedAt: number;
  player: {
    x: number;
    y: number;
    hp: number;
    maxHp: number;
    mana: number;
    maxMana: number;
    attack: number;
    defense: number;
    level: number;
    exp: number;
    expToNext: number;
    gold: number;
    weaponId: string;
    armorId: string;
    lastActionAt: number;
  };
  enemies: EnemyState[];
}

export interface CommandResult {
  ok: boolean;
  code: string;
  state: GameState;
  events: Array<Record<string, string | number | boolean>>;
}

interface ItemDefinition {
  slot: EquipmentSlot;
  attack: number;
  defense: number;
  maxHp: number;
  maxMana: number;
}

const ITEMS: Readonly<Record<string, ItemDefinition>> = Object.freeze({
  rust_blade: { slot: "weapon", attack: 6, defense: 0, maxHp: 0, maxMana: 0 },
  rift_saber: { slot: "weapon", attack: 14, defense: 0, maxHp: 0, maxMana: 0 },
  ash_vest: { slot: "armor", attack: 0, defense: 4, maxHp: 18, maxMana: 0 },
  warden_mail: { slot: "armor", attack: 0, defense: 10, maxHp: 42, maxMana: 0 },
});

const ENEMY_RULES: Readonly<Record<EnemyKind, { defense: number; exp: number; gold: number }>> = Object.freeze({
  warden: { defense: 9, exp: 24, gold: 7 },
  wraith: { defense: 3, exp: 18, gold: 5 },
  boss: { defense: 13, exp: 120, gold: 60 },
});

const ENEMY_ATTACKS: Readonly<Record<EnemyKind, { attack: number; range: number; cooldown: number }>> = Object.freeze({
  warden: { attack: 17, range: 66, cooldown: 1000 },
  wraith: { attack: 13, range: 76, cooldown: 720 },
  boss: { attack: 25, range: 92, cooldown: 1350 },
});

const ACTION_COOLDOWN_MS = Object.freeze({ attack: 240, skill1: 420, skill2: 700 });
const ACTION_RANGE = Object.freeze({ attack: 96, skill1: 112, skill2: 760 });
const WORLD_MIN_X = 16;
const WORLD_MAX_X = 2384;
const MAX_MOVE_ELAPSED_MS = 250;
const MOVE_SPEED_PER_SECOND = 250;

export function createInitialState(now: number): GameState {
  const state: GameState = {
    revision: 0,
    lastSeq: 0,
    updatedAt: now,
    player: {
      x: 180,
      y: 406,
      hp: 108,
      maxHp: 108,
      mana: 100,
      maxMana: 100,
      attack: 0,
      defense: 0,
      level: 1,
      exp: 0,
      expToNext: 100,
      gold: 0,
      weaponId: "rust_blade",
      armorId: "ash_vest",
      lastActionAt: 0,
    },
    enemies: [
      { id: "warden-1", kind: "warden", x: 620, hp: 105, maxHp: 105, alive: true, lastAttackAt: now },
      { id: "wraith-1", kind: "wraith", x: 1160, hp: 68, maxHp: 68, alive: true, lastAttackAt: now },
      { id: "boss-1", kind: "boss", x: 1970, hp: 420, maxHp: 420, alive: true, lastAttackAt: now },
    ],
  };
  recomputeStats(state, false);
  return state;
}

export function parseCommand(value: unknown): Command | null {
  if (!isRecord(value) || !Number.isSafeInteger(value.seq) || Number(value.seq) < 1 || typeof value.action !== "string") {
    return null;
  }
  const seq = Number(value.seq);
  if (value.action === "move" && (value.direction === -1 || value.direction === 0 || value.direction === 1) && exactKeys(value, ["seq", "action", "direction"])) {
    return { seq, action: "move", direction: value.direction };
  }
  if ((value.action === "jump" || value.action === "attack" || value.action === "sync") && exactKeys(value, ["seq", "action"])) {
    return { seq, action: value.action } as Command;
  }
  if (value.action === "skill" && (value.slot === 1 || value.slot === 2) && exactKeys(value, ["seq", "action", "slot"])) {
    return { seq, action: "skill", slot: value.slot };
  }
  if (value.action === "equip" && (value.slot === "weapon" || value.slot === "armor") && typeof value.itemId === "string" && exactKeys(value, ["seq", "action", "slot", "itemId"])) {
    return { seq, action: "equip", slot: value.slot, itemId: value.itemId };
  }
  return null;
}

export function applyCommand(input: GameState, command: Command, now: number): CommandResult {
  const state = structuredClone(input);
  const events: CommandResult["events"] = [];
  if (command.seq !== state.lastSeq + 1) {
    return { ok: false, code: "sequence_rejected", state: input, events };
  }
  if (!Number.isSafeInteger(now) || now < state.updatedAt) {
    return { ok: false, code: "clock_rejected", state: input, events };
  }
  if (now - state.updatedAt < 30) {
    return { ok: false, code: "rate_limited", state: input, events };
  }
  if (state.player.hp <= 0 && command.action !== "sync") {
    return { ok: false, code: "player_dead", state: input, events };
  }

  let accepted = true;
  let code = "accepted";
  switch (command.action) {
    case "move": {
      const elapsed = Math.min(MAX_MOVE_ELAPSED_MS, now - state.updatedAt);
      const distance = command.direction * MOVE_SPEED_PER_SECOND * (elapsed / 1000);
      state.player.x = round2(clamp(state.player.x + distance, WORLD_MIN_X, WORLD_MAX_X));
      break;
    }
    case "jump":
      events.push({ type: "jump", x: state.player.x });
      break;
    case "attack":
      ({ accepted, code } = resolveAttack(state, "attack", now, events));
      break;
    case "skill":
      ({ accepted, code } = resolveAttack(state, command.slot === 1 ? "skill1" : "skill2", now, events));
      break;
    case "equip":
      ({ accepted, code } = equip(state, command.slot, command.itemId));
      break;
    case "sync":
      break;
  }

  if (!accepted) {
    return { ok: false, code, state: input, events: [] };
  }
  resolveEnemyAttacks(state, now, events);
  state.lastSeq = command.seq;
  state.revision += 1;
  state.updatedAt = now;
  return { ok: true, code, state, events };
}

function resolveEnemyAttacks(state: GameState, now: number, events: CommandResult["events"]): void {
  if (state.player.hp <= 0) return;
  for (const enemy of state.enemies) {
    if (!enemy.alive) continue;
    const rule = ENEMY_ATTACKS[enemy.kind];
    if (Math.abs(enemy.x - state.player.x) > rule.range || now - enemy.lastAttackAt < rule.cooldown) continue;
    const damage = clamp(Math.round(rule.attack * (enemy.kind === "boss" ? 1.35 : 1)) - Math.floor(state.player.defense * 0.55), 1, 9999);
    enemy.lastAttackAt = now;
    state.player.hp = Math.max(0, state.player.hp - damage);
    events.push({ type: "player_damage", sourceId: enemy.id, amount: damage });
    if (state.player.hp === 0) {
      events.push({ type: "player_defeated" });
      return;
    }
  }
}

function resolveAttack(state: GameState, kind: "attack" | "skill1" | "skill2", now: number, events: CommandResult["events"]): { accepted: boolean; code: string } {
  const cooldown = ACTION_COOLDOWN_MS[kind];
  if (now - state.player.lastActionAt < cooldown) {
    return { accepted: false, code: "cooldown" };
  }
  const manaCost = kind === "skill1" ? 22 : kind === "skill2" ? 34 : 0;
  if (state.player.mana < manaCost) {
    return { accepted: false, code: "mana" };
  }
  const target = nearestEnemy(state, ACTION_RANGE[kind]);
  if (!target) {
    return { accepted: false, code: "no_target" };
  }

  const stats = canonicalStats(state);
  const multiplier = kind === "attack" ? 1 : kind === "skill1" ? 1.65 : 2.1;
  const defense = ENEMY_RULES[target.kind].defense;
  const damage = clamp(Math.round(stats.attack * multiplier) - Math.floor(defense * 0.55), 1, 9999);
  state.player.mana -= manaCost;
  state.player.lastActionAt = now;
  target.hp = Math.max(0, target.hp - damage);
  events.push({ type: "damage", targetId: target.id, amount: damage });
  if (target.hp === 0 && target.alive) {
    target.alive = false;
    grantRewards(state, ENEMY_RULES[target.kind].exp, ENEMY_RULES[target.kind].gold);
    events.push({ type: "defeated", targetId: target.id, exp: ENEMY_RULES[target.kind].exp, gold: ENEMY_RULES[target.kind].gold });
  }
  return { accepted: true, code: "accepted" };
}

function equip(state: GameState, slot: EquipmentSlot, itemId: string): { accepted: boolean; code: string } {
  const item = ITEMS[itemId];
  if (!item || item.slot !== slot) {
    return { accepted: false, code: "invalid_item" };
  }
  if (slot === "weapon") state.player.weaponId = itemId;
  else state.player.armorId = itemId;
  recomputeStats(state, true);
  return { accepted: true, code: "accepted" };
}

function nearestEnemy(state: GameState, maxDistance: number): EnemyState | undefined {
  return state.enemies
    .filter((enemy) => enemy.alive && Math.abs(enemy.x - state.player.x) <= maxDistance)
    .sort((a, b) => Math.abs(a.x - state.player.x) - Math.abs(b.x - state.player.x) || a.id.localeCompare(b.id))[0];
}

function canonicalStats(state: GameState): { attack: number; defense: number; maxHp: number; maxMana: number } {
  const weapon = ITEMS[state.player.weaponId] ?? ITEMS.rust_blade;
  const armor = ITEMS[state.player.armorId] ?? ITEMS.ash_vest;
  return {
    attack: 18 + (state.player.level - 1) * 2 + weapon.attack + armor.attack,
    defense: 4 + Math.floor(state.player.level / 3) + weapon.defense + armor.defense,
    maxHp: 122 + (state.player.level - 1) * 9 + weapon.maxHp + armor.maxHp,
    maxMana: 100 + (state.player.level - 1) * 3 + weapon.maxMana + armor.maxMana,
  };
}

function recomputeStats(state: GameState, preserveRatio: boolean): void {
  const beforeHp = state.player.maxHp || 1;
  const beforeMana = state.player.maxMana || 1;
  const hpRatio = state.player.hp / beforeHp;
  const manaRatio = state.player.mana / beforeMana;
  const stats = canonicalStats(state);
  state.player.maxHp = stats.maxHp;
  state.player.maxMana = stats.maxMana;
  state.player.attack = stats.attack;
  state.player.defense = stats.defense;
  state.player.hp = preserveRatio ? Math.max(1, Math.round(stats.maxHp * hpRatio)) : stats.maxHp;
  state.player.mana = preserveRatio ? Math.round(stats.maxMana * manaRatio) : stats.maxMana;
}

function grantRewards(state: GameState, exp: number, gold: number): void {
  state.player.exp += exp;
  state.player.gold += gold;
  while (state.player.exp >= state.player.expToNext) {
    state.player.exp -= state.player.expToNext;
    state.player.level += 1;
    state.player.expToNext = Math.round(state.player.expToNext * 1.24);
    recomputeStats(state, true);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function exactKeys(value: Record<string, unknown>, keys: string[]): boolean {
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}
