import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { parse2da } from '../src/area.js';
import { parseScriptApi, parseNcs } from '../src/ncs.js';
import { NwScriptVm } from '../src/nwscript_vm.js';
import { createCombatRound } from '../src/combat_round.js';
import { NativeRandom } from '../src/native_random.js';
import { difficultyOption } from '../src/difficulty.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';
import { clearAllAttacks } from '../src/combat_attack_data.js';

function fixture(options = {}) {
  const messages = [], cleared = [], s = new ModuleSession(null, { ...options,
    onMessage: m => messages.push(m), onClearActions: id => cleared.push(id) });
  s.characterRules = {
    damagetypes: parse2da(`2DA V2.0\n\nLabel\n${Array.from({ length: 13 }, (_, i) => `${i} Type`).join('\n')}`),
    excitedduration:parse2da('2DA V2.0\n\nDURATION\n0 0\n1 8000'),
    diffsettings: parse2da('2DA V2.0\n\nName A B C D E\n0 Critical 1 1 1 **** ****\n1 Ranged 1 1 1 **** ****\n2 Potion 1 1 1 **** ****\n3 Min 100 50 **** **** ****\n4 Max 25 50 100 100 200\n5 HP 1 **** **** **** ****\n6 Massive 0 0 0 1 1')
  };
  s.module = s.register('module', 'module', {}); s.ifo = {};
  // These lifecycle/effect fixtures isolate witness/XP providers. Integrated
  // faction/XP behavior is exercised separately with loaded active resources.
  s.combat.adjustReputations=async()=>{};s.combat.applyDeathExperience=async()=>{};
  const area = s.register('area', 'area', { objects: [], pvpSetting: 0 });
  const create = (name, isPC, hp) => {
    const object = s.register(isPC ? 'player' : 'creature', name, {
      name, isPC, nativeField89c:Number(isPC), areaId: area.id, position: [0, 0, 0], scripts: {}, factionId: isPC ? 0 : 1,
      authored: { Race: 0, FeatList: [], ClassList: [] }, creatureData: { CurrentHitPoints: hp, ClassList: [], Race: 0 },
      stats: { currentHP: hp, maxHP: 40, feats: [], equippedAbilities: { Dex: 10 } },
      combatRound: createCombatRound(s.characterRules), modelType: 'P', animationState: 1
    });
    area.objects.push(object.id); return object;
  };
  const pc = create('PC', true, 40), npc = create('NPC', false, 30); s.player = pc;
  s.random = new NativeRandom(1);
  const effect = (amount, flags = 4, creatorId = pc.id) => s.commands.EffectDamage([amount, flags], { self: creatorId });
  const apply = (value, target = npc) => s.commands.ApplyEffectToObject([0, value, target.id]);
  return { s, pc, npc, area, messages, cleared, effect, apply };
}
test('native-shaped strike signaling delivers attack history then delayed HP through live scheduler, retaining payload after round pool clear', async () => {
  const { s, pc, npc } = fixture(), round = pc.combatRound, data = round.attacks[0];
  pc.inventory = []; pc.creatureData.FeatList=[{Feat:21}];pc.stats.feats.push(21); // Suppress the separate unarmed AoO event using canonical ownership.
  data.result = 1; data.animationDuration = 857; data.attackDuration = 857; data.damage[12] = 8; data.targetId = npc.id;
  round.currentAttack = 1; const before = runtimeDiagnostics.records.length;
  await s.combat.signalMelee(pc, npc, 1);
  assert.deepEqual(s.scheduler.events.map(e => [e.event.eventId, e.due]), [[15, 0], [5, 428]]);
  assert.equal(npc.stats.currentHP, 30); const originalId = npc.id, originalStats = npc.stats;
  clearAllAttacks(round); await s.scheduler.pump();
  assert.equal(npc.stats.currentHP, 30);
  assert.equal(npc.lastAttackerId,pc.id);assert.equal(npc.nativeField700,1);assert.equal(pc.nativeField700,1);
  assert.equal(npc.lastAttackType,0);assert.equal(npc.lastAttackMode,0);
  assert.ok(!runtimeDiagnostics.records.slice(before).some(record => /AI event 15/.test(record.message)));
  s.scheduler.advance(427); await s.scheduler.pump(); assert.equal(npc.stats.currentHP, 30);
  s.scheduler.advance(1); await s.scheduler.pump(); assert.equal(npc.stats.currentHP, 22);
  assert.equal(s.registry.get(originalId), npc); assert.equal(npc.stats, originalStats); assert.equal(npc.lastDamagerId, pc.id);
});

test('live death magic immunity preserves killer/status/action state and emits caster feedback before an explicit bypass permits death',async()=>{
  const {s,pc,npc,cleared}=fixture(),sent=[];s.onCombatMessage=m=>sent.push(m);
  npc.effects=[{...s.effects.create(22,OBJECT_INVALID,[32,28,0,0]),durationType:2}];
  const effect=s.effects.create(2,pc.id,[],8);effect.spellId=4;npc.lastKillerId=0x80000001;
  await s.damage.death(npc,effect);
  assert.equal(npc.nativeDeathWord8d4,65535);assert.equal(npc.lastKillerId,0x80000001);assert.deepEqual(cleared,[]);
  assert.equal(sent.length,1);assert.equal(sent[0].recipientId,pc.id);assert.equal(sent[0].data.integers[9],127);assert.deepEqual(sent[0].data.objects,[npc.id]);
  effect.bypassImmunity=1;await s.damage.death(npc,effect);assert.equal(npc.nativeDeathWord8d4,0);assert.equal(npc.lastKillerId,pc.id);assert.deepEqual(cleared,[npc.id]);
});
test('native IsImmortal serialized field protects NPC HP without requiring an invented runtime override', async () => {
  const { npc, effect, apply } = fixture();
  npc.creatureData.IsImmortal = 1; await apply(effect(50)); assert.equal(npc.stats.currentHP, 1);
  npc.stats.currentHP = 30; npc.creatureData.IsImmortal = 0;
  await apply(effect(20)); assert.equal(npc.stats.currentHP, 10);
});

test('native damage broadcasts each endpoint before its initiative and commits history afterwards',async()=>{
  const {s,pc,npc,effect,apply}=fixture(),seen=[];
  pc.initiativePending=npc.initiativePending=1;
  const initiative=s.damage.initiative.bind(s.damage);
  s.damage.initiative=o=>{
    seen.push([o.id,o.nativeField700,o.nativeField704,o.lastDamagerId??OBJECT_INVALID]);
    initiative(o);
  };
  await apply(effect(3));
  assert.deepEqual(seen,[[npc.id,1,8000,OBJECT_INVALID],[pc.id,1,8000,OBJECT_INVALID]]);
  assert.equal(npc.lastDamagerId,pc.id);assert.equal(npc.stats.currentHP,27);
});

// Owned bytecode, decoded by the actual NCS parser and executed by the VM.
function bytecode(name, rows) {
  const code = [], u16 = n => code.push(n >>> 8 & 255, n & 255), i32 = n => code.push(n >>> 24 & 255, n >>> 16 & 255, n >>> 8 & 255, n & 255);
  for (const [op, type = 0, value, argc] of rows) {
    code.push(op, type);
    if (op === 4 && type === 5) { const b = new TextEncoder().encode(value); u16(b.length); code.push(...b); }
    else if (op === 4 || op === 0x1b) i32(value);
    else if (op === 5) { u16(value); code.push(argc); }
  }
  const b = new Uint8Array(13 + code.length); b.set(new TextEncoder().encode('NCS V1.0')); b[8] = 0x42;
  new DataView(b.buffer).setUint32(9, b.length); b.set(code, 13); return parseNcs(b, name);
}

test('difficulty uses physical table positions, byte narrowing and native missing-cell zero', () => {
  const { s } = fixture();
  assert.equal(s.commands.GetGameDifficulty(), 2); assert.equal(s.getDifficultyOption(4), 100); assert.equal(s.getDifficultyOption(5), 0);
  assert.equal(difficultyOption(s.characterRules.diffsettings, 0, 5), 1);
  const custom = parse2da('2DA V2.0\n\nLabel Whatever Other X Y Z\n91 HP 0x101 -1 300 **** ****');
  assert.equal(difficultyOption(custom, 0, 0), 1); assert.equal(difficultyOption(custom, 1, 0), 255);
  assert.equal(difficultyOption(custom, 2, 0), 44); assert.equal(difficultyOption(custom, 3, 0), 0);
  assert.throws(() => difficultyOption(custom, 5, 0), /unavailable/);
});

test('energy bonus adapter consumes live resistance before updating the caller-owned attack record', async () => {
  const { s, pc, npc, messages } = fixture();
  s.characterRules.iprp_damagecost = parse2da('2DA V2.0\n\nRank NumDice Die\n0 0 0 0\n1 1 0 10');
  const self = { self: pc.id }, hp = npc.stats.currentHP;
  const bonus = s.commands.EffectDamageIncrease([1, 8], self);
  const immunity = s.commands.EffectDamageImmunityIncrease([8, 50], self);
  const resistance = s.commands.EffectDamageResistance([8, 4, 3], self);
  await s.commands.ApplyEffectToObject([2, bonus, pc.id]);
  // A hand-specific source takes the native exact-flag mitigation path.
  pc.effects[0].integers[5] = 1;
  await s.commands.ApplyEffectToObject([2, immunity, npc.id]);
  await s.commands.ApplyEffectToObject([2, resistance, npc.id]);
  const attack = { weaponAttackType: 1, ranged: 0, result: 1, damage: Array(32).fill(-1) };
  const query = await s.damage.effectBonus(pc, npc, attack, { energy: true, maximize: true });
  assert.equal(query.total, 2); assert.equal(attack.damage[3], -1);
  assert.equal(npc.effects.find(e => e.id === resistance.id).integers[2], 3, 'Simulation retains the live capacity');
  const applied = await s.damage.effectBonus(pc, npc, attack, { energy: true });
  assert.equal(applied.total, 2); assert.equal(attack.damage[3], 2);
  assert.equal(npc.effects.some(e => e.id === resistance.id), false);
  assert.equal(npc.stats.currentHP, hp, 'Attack-record resolution alone does not subtract HP');
  assert.deepEqual(messages.filter(m => m.type === 'combatFeedback').map(m => [m.code, m.amount]), [[66, 3]]);
  assert.equal((await s.damage.effectBonus(pc, npc, attack, { energy: true })).total, 5);
  assert.equal(attack.damage[3], 7, 'Subsequent query sees the immediately removed live effect');
});

test('damage applies immunity, live resistance budgets and reduction in order, with immediate removal', async () => {
  const { s, pc, npc, messages, effect, apply } = fixture(), self = { self: pc.id }, shared = npc.stats, id = npc.id;
  const immunity = s.commands.EffectDamageImmunityIncrease([4, 50], self);
  const resist = s.commands.EffectDamageResistance([4, 5, 3], self);
  const reduce = s.commands.EffectDamageReduction([2, 1, 3], self);
  for (const value of [immunity, resist, reduce]) await s.commands.ApplyEffectToObject([2, value, id]);
  assert.equal(s.commands.GetEffectType([resist]), 1); assert.equal(s.commands.GetEffectType([reduce]), 7);
  await apply(effect(20));
  assert.equal(s.hitPoints(id, false), 25, '20 -> 10 immunity -> 7 finite resistance -> 5 reduction');
  assert.equal(npc.effects.some(e => e.id === resist.id), false);
  assert.equal(npc.effects.find(e => e.id === reduce.id).integers[2], 1);
  assert.deepEqual(messages.filter(m => m.type === 'combatFeedback').map(m => [m.code, m.amount]), [[66, 3], [67, 2]]);
  assert.equal(s.commands.GetLastDamager([id]), pc.id); assert.equal(s.commands.GetTotalDamageDealt([], { self: id }), 5);
  assert.equal(s.commands.GetDamageDealtByType([4], { self: id }), 5);
  assert.equal(s.commands.GetDamageDealtByType([3], { self: id }), 0);
  assert.equal(s.commands.GetDamageDealtByType([1], { self: id }), -1);
  assert.equal(npc.stats, shared); assert.equal(s.registry.get(id), npc); assert.equal(npc.creatureData.CurrentHitPoints, 25);
  assert.equal(npc.effects.some(e => e.type === 38), false, 'Damage consumes its effect even for permanent application');
});

test('mitigation constructors preserve native signed resistance fields and clamp reduction independently', () => {
  const { s, pc } = fixture(), self = { self: pc.id };
  assert.deepEqual(s.commands.EffectDamageResistance([-1, -5, -1, 2], self).integers, [8, -5, -1, 2, 0, 0, 0, 0]);
  assert.deepEqual(s.commands.EffectDamageResistance([0, 5], self).integers, [0, 5, 0, 0, 0, 0, 0, 0]);
  assert.deepEqual(s.commands.EffectDamageReduction([-2, 23, -10, -1], self).integers, [0, 0, 0, -1, 0, 0, 0, 0]);
});

test('temporary HP and healing share base storage, total getter and immutable authored state', async () => {
  const { s, pc, npc, effect, apply } = fixture(), authored = structuredClone(npc.authored), self = { self: pc.id };
  npc.stats.currentHP = 20;
  const temp = s.commands.EffectTemporaryHitpoints([8], self);
  assert.equal(s.commands.GetEffectType([temp]), 9);
  s.commands.ApplyEffectToObject([2, temp, npc.id]);
  assert.equal(npc.stats.currentHP, 20); assert.equal(s.hitPoints(npc.id, false), 28);
  await s.commands.ApplyEffectToObject([0, s.commands.EffectHeal([5], self), npc.id]);
  assert.equal(npc.stats.currentHP, 25); assert.equal(s.hitPoints(npc.id, false), 33);
  await apply(effect(6));
  assert.equal(npc.stats.currentHP, 25); assert.equal(npc.stats.temporaryHP, 2);
  assert.equal(npc.effects.find(e => e.id === temp.id).integers[0], 2);
  await apply(effect(5));
  assert.equal(npc.stats.currentHP, 22); assert.equal(s.hitPoints(npc.id, false), 22);
  assert.equal(npc.effects.length, 0); assert.deepEqual(npc.authored, authored);
});

test('creature OnDamaged executes inside the damage call and can heal before its feedback snapshot', async () => {
  const { s, pc, npc, messages, effect, apply } = fixture();
  const api = parseScriptApi('object GetLastDamager(object o=OBJECT_SELF); void SetLocalObject(object o,string n,object v); int GetTotalDamageDealt(); void SetLocalInt(object o,string n,int v); effect EffectHeal(int n); void ApplyEffectToObject(int d,effect e,object o,float f=0.0);');
  const script = bytecode('on_damage', [[4, 6, 0], [5, 0, 0, 1], [4, 5, 'damager'], [4, 6, 0], [5, 0, 1, 3],
    [5, 0, 2, 0], [4, 5, 'damage'], [4, 6, 0], [5, 0, 3, 3],
    [4, 6, 0], [4, 3, 2], [5, 0, 4, 1], [4, 3, 0], [5, 0, 5, 3], [0x20]]);
  s.vm = new NwScriptVm({ api, command: name => s.commands[name] }); s.program = async () => script; npc.scripts.damaged = script.name;
  await apply(effect(7));
  assert.equal(npc.locals.getObject('damager'), pc.id); assert.equal(npc.locals.getInt('damage'), 7);
  assert.equal(s.hitPoints(npc.id, false), 25);
  assert.deepEqual(messages.filter(m => ['heal', 'damage'].includes(m.type)).map(m => m.type), ['heal', 'damage']);
  assert.equal(s.scheduler.events.length, 0, 'The native creature event is direct');
});

test('live AI round end executes authored NCS before the same creature expires temporary HP', async () => {
  const { s, pc, npc } = fixture(), id = npc.id;
  const api = parseScriptApi('int GetCurrentHitPoints(object o=OBJECT_SELF); void SetLocalInt(object o,string n,int v);');
  const script = bytecode('on_round_end', [[4, 6, 0], [5, 0, 0, 1], [4, 5, 'end_hp'], [4, 6, 0], [5, 0, 1, 3], [0x20]]);
  s.vm = new NwScriptVm({ api, command: name => s.commands[name] }); s.program = async () => script; npc.scripts.roundEnd = script.name;
  s.commands.ApplyEffectToObject([1, s.commands.EffectTemporaryHitpoints([5], { self: pc.id }), id, 1]);
  npc.combatRound.started = true; npc.combatRound.length = 1000;
  s.scheduler.advance(1000); await s.scheduler.pump();
  assert.equal(npc.locals.getInt('end_hp'), 0); assert.equal(npc.combatRound.started, true);
  s.scheduler.advance(1); await s.scheduler.pump();
  assert.equal(npc.locals.getInt('end_hp'), 35); assert.equal(s.hitPoints(id, false), 30);
  assert.equal(npc.combatRound.started, false); assert.equal(npc.effects.length, 0);
  assert.equal(s.scheduler.events.length, 0, 'Round-end event is direct');
});

test('damage reaction extends an existing pause owned by the same creator', () => {
  const { s, pc, npc, effect } = fixture();
  npc.combatRound.paused = true; npc.combatRound.pausedBy = pc.id; npc.combatRound.pauseTimer = 300;
  s.damage.reaction(npc, effect(3));
  assert.equal(npc.combatRound.pauseTimer, 1300);
});

test('multi-component creature history preserves native overwritten totals without subtracting HP twice', async () => {
  const { s, npc, effect, apply } = fixture(), value = effect(3);
  value.integers[8] = 4;
  await apply(value);
  assert.equal(npc.stats.currentHP, 23); assert.equal(npc.lastDamage[2], 7); assert.equal(npc.lastDamage[8], 7);
  assert.equal(s.commands.GetTotalDamageDealt([], { self: npc.id }), 14);
});

test('processed combat damage is not mitigated twice and zero damage leaves history unchanged', async () => {
  const { s, pc, npc, effect, apply } = fixture();
  s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityIncrease([4, 100], { self: pc.id }), npc.id]);
  const value = effect(9); value.integers[36] = 1;
  await apply(value); assert.equal(npc.stats.currentHP, 21); assert.equal(npc.lastDamage[2], 9);
  await apply(effect(0)); assert.equal(npc.stats.currentHP, 21); assert.equal(npc.lastDamage[2], 9);
});

test('NPC death skips OnDamaged, runs OnDeath before effect purge and retains the canonical object', async () => {
  const { s, pc, npc, messages, cleared, effect, apply } = fixture(), trace = [], self = { self: pc.id };
  const temp = s.commands.EffectTemporaryHitpoints([2], self);
  s.commands.ApplyEffectToObject([2, temp, npc.id]);
  await s.commands.ApplyEffectToObject([2, s.commands.EffectDamageImmunityIncrease([256, 50], self), npc.id]);
  npc.scripts = { damaged: 'wrong', death: 'death' };
  s.program = async name => ({ name }); s.vm = { async run(program, id) { trace.push([program.name, id, s.hitPoints(id, false), npc.effects.length, s.commands.GetLastKiller([], { self: id })]); } };
  await apply(effect(40));
  assert.deepEqual(trace, [['death', npc.id, -8, 2, pc.id]]);
  assert.equal(npc.effects.length, 0); assert.equal(npc.stats.currentHP, -11); assert.equal(npc.deathHandled, true);
  assert.deepEqual(cleared, [npc.id]); assert.equal(s.registry.get(npc.id), npc);
  assert.deepEqual(messages.filter(m => ['damage', 'death'].includes(m.type)).map(m => m.type), ['damage', 'death']);
  await apply(effect(1)); assert.equal(trace.length, 1);
});
test('native death clears actions, adjusts witnesses before assigning killer, then runs script and XP before clearing the shared status WORD',async()=>{
  const {s,pc,npc,effect}=fixture(),trace=[];npc.lastKillerId=OBJECT_INVALID;npc.lastDamagerId=pc.id;
  s.combat.clearActions=o=>trace.push(['actions',o.nativeField8d4]);
  s.combat.adjustReputations=(target,killer,kind)=>trace.push(['reputations',target,killer,kind,npc.lastKillerId]);
  s.combat.clearAttackActivity=(o,bit,value)=>trace.push(['activity',bit,value,o.lastKillerId]);
  s.combat.removeInvisibility=o=>trace.push(['invisibility',o.lastKillerId]);
  npc.scripts.death='death';s.program=async()=>({});s.vm={run:async()=>trace.push(['script',npc.lastKillerId,npc.nativeField8d4])};
  s.combat.applyDeathExperience=o=>trace.push(['xp',o.lastKillerId,o.nativeField8d4]);
  await s.damage.death(npc,effect(1,4,npc.id));
  assert.deepEqual(trace,[['actions',65535],['reputations',npc.id,pc.id,2,OBJECT_INVALID],['activity',1,0,OBJECT_INVALID],
    ['invisibility',OBJECT_INVALID],['script',pc.id,65535],['xp',pc.id,65535]]);
  assert.equal(npc.nativeMovementFlags8d4,0);assert.equal(npc.perceptionUpdateFlags,0);assert.equal(npc.nativeDeathWord8d4,0);
  trace.length=0;await s.damage.death(npc,effect(1));assert.deepEqual(trace,[]);
});

test('PC dying/death enqueue distinct module events after damage, and dying suppresses a death event', async () => {
  const { s, pc, npc, effect, apply } = fixture(); s.ifo = { Mod_OnPlrDying: 'dying', Mod_OnPlrDeath: 'dead' };
  pc.stats.currentHP = 3;
  await apply(effect(6, 4, npc.id), pc);
  assert.equal(s.isDying(pc), true); assert.equal(s.isDead(pc), false);
  assert.deepEqual(s.scheduler.events.map(e => [e.targetId, e.event.name, e.event.eventObjects]), [[s.module.id, 'dying', { dying: pc.id }]]);
  await apply(effect(8, 4, npc.id), pc);
  assert.equal(s.isDead(pc), true);
  assert.deepEqual(s.scheduler.events.map(e => e.event.name), ['dying', 'dead']);
});

test('native dying/death getters retain separate module histories across callers and empty scripts', async () => {
  const { s, pc, npc, effect, apply } = fixture();
  pc.stats.currentHP = 2;
  await apply(effect(3, 8, npc.id), pc);
  assert.equal(s.scheduler.events[0].event.nativeEventId, 32);
  assert.equal(s.commands.GetLastPlayerDying([], { self: s.module.id }), OBJECT_INVALID);
  await s.scheduler.pump();
  assert.equal(s.commands.GetLastPlayerDying([], { self: npc.id }), pc.id);
  assert.equal(s.commands.GetLastPlayerDied([], { self: npc.id }), OBJECT_INVALID);
  s.module.eventObjects.entering = npc.id;
  assert.equal(s.commands.GetEnteringObject([], { self: s.module.id }), npc.id);
  await apply(effect(10, 8, npc.id), pc);
  assert.equal(s.commands.GetLastPlayerDied([], { self: npc.id }), OBJECT_INVALID, 'Queueing does not dispatch module context');
  await s.scheduler.pump();
  assert.equal(s.commands.GetLastPlayerDied([], { self: npc.id }), pc.id);
  assert.equal(s.commands.GetLastPlayerDying([], { self: npc.id }), pc.id);
  assert.equal(s.commands.GetEnteringObject([], { self: s.module.id }), npc.id);
  s.module = null;
  assert.equal(s.commands.GetLastPlayerDying([], { self: npc.id }), OBJECT_INVALID);
  assert.equal(s.commands.GetLastPlayerDied([], { self: npc.id }), OBJECT_INVALID);
});

test('temporary HP removal runs its hook while the live handle remains visible and can cause death', async () => {
  const { s, pc, npc } = fixture(), self = { self: pc.id }, trace = [];
  npc.stats.currentHP = 0;
  // A loaded living creature can have zero base HP protected by temporary HP.
  npc.stats.currentHP = 1;
  const temp = s.commands.EffectTemporaryHitpoints([4], self); s.commands.ApplyEffectToObject([2, temp, npc.id]);
  npc.stats.currentHP = 0; npc.scripts.death = 'death'; s.program = async name => ({ name });
  s.vm = { async run() { trace.push([npc.effects.some(e => e.id === temp.id), s.hitPoints(npc.id, false)]); } };
  s.effects.requestRemoval(npc.id, temp, pc.id);
  assert.equal(s.hitPoints(npc.id, false), 4); assert.equal(s.isDead(npc), false);
  await s.scheduler.pump();
  assert.deepEqual(trace, [[true, 0]]); assert.equal(npc.effects.length, 0); assert.equal(s.isDead(npc), true);
  assert.equal(npc.lastKillerId, OBJECT_INVALID, 'Native temp HP removal creates death with invalid creator');
});

test('expiry and asynchronous lifecycle scripts are serialized with scheduler dispatch', async () => {
  const { s, pc, npc } = fixture(), self = { self: pc.id }, trace = [];
  npc.stats.currentHP = 1;
  const temp = s.commands.EffectTemporaryHitpoints([4], self); s.commands.ApplyEffectToObject([1, temp, npc.id, 0.01]);
  npc.stats.currentHP = 0; npc.scripts.death = 'death';
  let release, entered;
  const started = new Promise(resolve => { entered = resolve; }), waiting = new Promise(resolve => { release = resolve; });
  s.program = async name => ({ name }); s.vm = { async run(p) { trace.push(p.name); if (p.name === 'death') { entered(); await waiting; } } };
  s.queueScript('after', pc.id); s.scheduler.advance(11);
  const pump = s.scheduler.pump(); await started;
  await s.scheduler.pump(); assert.deepEqual(trace, ['death']);
  release(); await pump;
  assert.deepEqual(trace, ['death', 'after']); assert.equal(npc.effects.length, 0);
});

test('door/placeable OnDamaged is queued and uses hardness while history retains original components', async () => {
  const { s, pc, area, messages, effect, apply } = fixture(), trace = [];
  const door = s.register('door', 'door', { areaId: area.id, authored: { HP: 20, CurrentHP: 20, Hardness: 3 }, scripts: { damaged: 'door_hit' }, animationState: 0 });
  s.program = async name => ({ name }); s.vm = { async run(p, id) { trace.push([p.name, s.commands.GetLastDamager([id]), s.commands.GetTotalDamageDealt([], { self: id })]); } };
  await apply(effect(8), door);
  assert.equal(s.hitPoints(door.id, false), 15); assert.equal(trace.length, 0); assert.equal(door.lastDamage[2], 8);
  assert.equal(messages.at(-1).type, 'damage');
  await s.scheduler.pump(); assert.deepEqual(trace, [['door_hit', pc.id, 8]]);
});

test('plot damage is zero but still invokes OnDamaged; difficulty and immortal clipping are live', async () => {
  const { s, pc, npc, effect, apply } = fixture({ difficultyLevel: 0 }), trace = [];
  npc.plot = true; npc.scripts.damaged = 'plot_damage'; s.program = async name => ({ name }); s.vm = { async run(p) { trace.push(p.name); } };
  await apply(effect(9)); assert.equal(npc.stats.currentHP, 30); assert.deepEqual(trace, ['plot_damage']); assert.equal(npc.lastDamage[2], 0);
  pc.stats.currentHP = 3; await apply(effect(20, 4, npc.id), pc); assert.equal(pc.stats.currentHP, 1);
  npc.plot = false; npc.immortal = 1; await apply(effect(40)); assert.equal(npc.stats.currentHP, 1);
});

test('unavailable enchantment/status work fails before HP or RNG changes and is retained in diagnostics', async () => {
  const { s, npc, effect, apply } = fixture();
  for (const setup of [() => { npc.animationState = 1; npc.effects = [{ type: 8, integers: [] }]; }]) {
    setup(); const draws = s.random.draws;
    await assert.rejects(apply(effect(7)), /not implemented/);
    assert.equal(npc.stats.currentHP, 30); assert.equal(s.random.draws, draws);
  }
  assert.ok(runtimeDiagnostics.records.some(r => r.code === 'combat.lifecycle-unimplemented' && r.context.objectId === npc.id && /status/.test(r.message)));
});
test('two live shields reflect processed weapon damage once, including zero damage, and skip spell/reflected damage',async()=>{
 const {s,pc,npc,effect,apply}=fixture();
 s.characterRules.iprp_damagecost=parse2da('2DA V2.0\n\nNumDice Die\n0 0 4');
 s.characterRules.damagehitvisual=parse2da('2DA V2.0\n\nVisualEffectID\n'+Array.from({length:13},(_,i)=>`${i} 0`).join('\n'));
 s.characterRules.visualeffects=parse2da('2DA V2.0\n\nType_FD\n0 F');
 for(const o of [pc,npc])await s.effects.apply(2,s.commands.EffectDamageShield([3,0,8],{self:o.id}),o.id);
 const weapon=effect(5);weapon.integers[36]=1;await apply(weapon);assert.equal(npc.stats.currentHP,25);assert.equal(pc.stats.currentHP,33);
 await apply(effect(5));assert.equal(npc.stats.currentHP,20);assert.equal(pc.stats.currentHP,33,'script damage is not processed weapon damage');
 const zero=effect(0);zero.integers[36]=1;await apply(zero);assert.equal(npc.stats.currentHP,20);assert.equal(pc.stats.currentHP,26);
 const reflected=effect(5);reflected.integers[36]=1;reflected.integers[37]=1;await apply(reflected);assert.equal(npc.stats.currentHP,15);assert.equal(pc.stats.currentHP,26);
});

test('direct OnDamaged script failures are diagnosed and do not prevent damage/death completion', async () => {
  const { s, npc, messages, effect, apply } = fixture();
  npc.scripts.damaged = 'broken'; s.program = async name => ({ name }); s.vm = { async run() { throw new Error('unsupported test command'); } };
  await apply(effect(2)); assert.equal(npc.stats.currentHP, 28); assert.equal(messages.at(-1).type, 'damage');
  assert.ok(s.diagnostics.includes('unsupported test command'));
});

test('initiative consumes a d20 before bonuses, takes superior over improved, and does not reroll until pending', () => {
  const { s, pc, messages } = fixture();
  pc.initiativePending = 1; pc.stats.equippedAbilities.Dex = 14; pc.stats.feats = [753, 377, 379, 402];
  s.damage.initiative(pc);
  assert.equal(s.random.draws, 1); assert.equal(pc.initiativeRoll, 16);
  assert.deepEqual([messages.at(-1).roll, messages.at(-1).modifier], [2, 14]);
  s.damage.initiative(pc); assert.equal(s.random.draws, 1);
});

test('damage reaction uses native MODELTYPE and branch-dependent RNG count, and respects another pause owner', () => {
  for (const [modelType, draws, animation, count] of [['PF', [0], 23, 1], ['P', [0, 0], 77, 2], ['P', [1, 1, 1], 99, 3]]) {
    const { s, npc, effect } = fixture(); npc.modelType = modelType; let consumed = 0;
    s.random = { next() { return draws[consumed++]; } };
    s.damage.reaction(npc, effect(3));
    assert.equal(npc.animationState, animation); assert.equal(consumed, count);
    assert.equal(npc.combatRound.paused, true); assert.equal(npc.combatRound.pauseTimer, 1000);
  }
  const { s, npc, effect } = fixture(); npc.combatRound.paused = true; npc.combatRound.pausedBy = 999;
  s.damage.reaction(npc, effect(3)); assert.equal(s.random.draws, 0); assert.equal(npc.animationState, 1);
});

test('damage preserves creator ID zero, external target IDs and wide effect handles', async () => {
  const { s, npc, effect, apply } = fixture();
  const external = { ...npc, stats: structuredClone(npc.stats), effects: [], scripts: {} };
  const added = s.registry.addExternalObject(5, external);
  assert.equal(added.status, 0); assert.equal(external.id, 0x80000005);
  s.effects.nextId = 0x20000000000001n;
  const value = effect(3, 8, 0); assert.equal(value.creatorId, 0); assert.equal(value.id, '0020000000000001');
  await apply(value, external);
  assert.equal(s.commands.GetLastDamager([external.id]), 0); assert.equal(s.registry.get(external.id), external);
  assert.equal(external.stats.currentHP, 27);
});

test('last-hostile queries invalidate dead, dying, removed or plot-disallowed references', () => {
  const { s, pc, npc } = fixture();
  npc.lastHostileActorId = pc.id; assert.equal(s.commands.GetLastHostileActor([npc.id]), pc.id);
  pc.stats.currentHP = 0;
  assert.equal(s.commands.GetLastHostileActor([npc.id]), OBJECT_INVALID); assert.equal(npc.lastHostileActorId, OBJECT_INVALID);
  pc.stats.currentHP = 10; npc.lastHostileActorId = pc.id; npc.plot = true;
  assert.equal(s.commands.GetLastHostileActor([npc.id]), OBJECT_INVALID);
  npc.plot = false; npc.lastHostileActorId = pc.id; s.unregister(pc.id);
  assert.equal(s.commands.GetLastHostileActor([npc.id]), OBJECT_INVALID);
});

test('combat script getters read generic live alignment, trap and canonical target state', () => {
  const { s, pc, npc } = fixture();
  npc.creatureData.GoodEvil = 20; npc.creatureData.LawfulChaotic = 75;
  assert.equal(s.commands.GetAlignmentGoodEvil([npc.id]), 5); assert.equal(s.commands.GetAlignmentLawChaos([npc.id]), 2);
  assert.equal(s.commands.GetAlignmentGoodEvil([OBJECT_INVALID]), -1);
  assert.equal(s.commands.GetIsTrapped([npc.id]), 0);
  const trap = s.register('trigger', 'trap', { authored: { Type: 2 } });
  assert.equal(s.commands.GetIsTrapped([trap.id]), 1); trap.trapped = 0; assert.equal(s.commands.GetIsTrapped([trap.id]), 0);
  npc.nativeAttackTarget724 = pc.id; npc.attackTargetId = OBJECT_INVALID;
  assert.equal(s.commands.GetAttackTarget([npc.id]), pc.id);
  assert.equal(s.commands.GetAttackTarget([trap.id]), OBJECT_INVALID);
});

test('GetMaster reads the stored canonical reference without resolving it and records inconsistent ownership', () => {
  const { s, pc, npc } = fixture();
  assert.equal(s.commands.GetMaster([npc.id]), OBJECT_INVALID);
  assert.equal(s.commands.GetMaster([s.module.id]), OBJECT_INVALID);
  assert.equal(s.commands.GetMaster([OBJECT_INVALID]), OBJECT_INVALID);
  npc.masterId = 0; npc.associateType = 1;
  assert.equal(s.commands.GetMaster([npc.id]), 0);
  npc.masterId = 0x80000005;
  assert.equal(s.commands.GetMaster([npc.id]), 0x80000005, 'Unresolved external IDs remain stored references');
  npc.associateType = 0;
  const sequence = runtimeDiagnostics.records.length;
  assert.equal(s.commands.GetMaster([npc.id]), 0x80000005);
  assert.equal(runtimeDiagnostics.records[sequence].code, 'object.associate-inconsistent');
  assert.equal(runtimeDiagnostics.records[sequence].context.objectId, npc.id);
  npc.masterId = pc.id;
  s.registry.delete(pc.id);
  assert.equal(s.commands.GetMaster([npc.id]), pc.id, 'Native getter preserves a reference to a deleted master');
});
