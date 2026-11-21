import test from 'node:test';
import assert from 'node:assert/strict';
import { addAttackRequest } from '../src/combat_request.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function fixture() {
  const actor = { id: 0x80000001, commandable: 1, creatureState: 0, creatureAnimation: 1,
    currentAITargetId: OBJECT_INVALID, nativeField700: 0, isPC: true }, trace = [];
  const target = { id: 0, creature: true, isPC: true };
  const providers = {
    computeAIState: () => trace.push('compute'), feedback: (a, value) => trace.push(['feedback', value]),
    visibilityFlags: () => null, getObject: id => target, asCreature: o => o.creature ? o : null,
    aiReaction: () => 0, isDM: () => 0, getDead: () => 0,
    clearActions: () => trace.push('clear'), actionManager: (a, value) => trace.push(['manager', value]),
    enqueueAction: (a, ...args) => trace.push(['queue', ...args]), getCreature: () => target,
    broadcastAssociateCommand: (c, value) => trace.push(['associate', c.attackTargetId, value]),
    broadcastBattleCry: () => trace.push('cry'), broadcastCombatState: () => trace.push('state'),
    resolveInitiative: () => trace.push('initiative'), getDoor: () => null, doorFieldFC: () => 0,
    enqueueDoorEvent: (...args) => trace.push(['door', ...args]),
    random: { draws: 0, next() { this.draws++; return 2; } }
  };
  return { actor, target, trace, providers };
}

test('native attack request preserves canonical zero, front insertion, associate target and callback/RNG order', async () => {
  const { actor, target, trace, providers } = fixture();
  assert.equal(await addAttackRequest(actor, 0, -3, 1, 1, providers), 1);
  assert.deepEqual(trace, ['compute', 'clear', ['manager', 4], ['queue', 12, 65535, 3, 0, true],
    ['associate', actor.id, -16], 'cry', 'state', 'initiative']);
  assert.equal(actor.attackActionTargetId, 0); assert.equal(actor.nativeAttackTarget724, OBJECT_INVALID);
  assert.equal(actor.passiveAttack, -3); assert.equal(target.attackTargetId, actor.id);
  assert.equal(providers.random.draws, 1);
});

test('native request rejections clear +724/+728 but retain +738 and avoid RNG/queue work', async () => {
  for (const gate of ['commandable', 'state', 'visibility', 'reaction', 'dm', 'dead']) {
    const { actor, providers, trace } = fixture();
    actor.attackActionTargetId = 10; actor.nativeAttackTarget724 = 20; actor.attackTargetId = 30;
    if (gate === 'commandable') actor.commandable = 0;
    if (gate === 'state') actor.creatureState = 5;
    if (gate === 'visibility') providers.visibilityFlags = () => 0x14;
    if (gate === 'reaction') providers.aiReaction = () => 257;
    if (gate === 'dm') { actor.isPC = false; providers.isDM = () => 1; }
    if (gate === 'dead') providers.getDead = () => 1;
    assert.equal(await addAttackRequest(actor, 0, 0, 1, 0, providers), 0, gate);
    assert.equal(actor.attackActionTargetId, OBJECT_INVALID); assert.equal(actor.nativeAttackTarget724, OBJECT_INVALID);
    assert.equal(actor.attackTargetId, 30); assert.equal(providers.random.draws, 0);
    assert.ok(!trace.some(v => Array.isArray(v) && v[0] === 'queue'));
    if (gate === 'state') assert.deepEqual(trace, ['compute', ['feedback', 7]]);
    if (gate === 'reaction') assert.deepEqual(trace, ['compute', ['feedback', 187]]);
  }
});

test('already attacking same target skips clear/queue/RNG but still posts exact-one door event', async () => {
  for (const field of [0, 1, 2]) {
    const { actor, providers, trace } = fixture();
    actor.creatureAnimation = 258; actor.currentAITargetId = 0;
    providers.getDoor = () => ({}); providers.doorFieldFC = () => field;
    assert.equal(await addAttackRequest(actor, 0, 0, 1, 0, providers), 1);
    assert.deepEqual(trace, field === 1 ? ['compute', ['door', actor.id, 0, 34, 0]] : ['compute']);
    assert.equal(providers.random.draws, 0); assert.equal(actor.attackActionTargetId, OBJECT_INVALID);
  }
});

test('invalid sentinel allows clear but no attack; unresolved or noncreature targets still enqueue', async () => {
  const { actor, providers, trace } = fixture();
  providers.getObject = () => { assert.fail('Sentinel must not query a game object'); };
  assert.equal(await addAttackRequest(actor, OBJECT_INVALID, 4, 1, 0, providers), 1);
  assert.deepEqual(trace, ['compute', 'clear']); assert.equal(providers.random.draws, 0);
  for (const object of [null, { creature: false }]) {
    const f = fixture(); f.providers.getObject = () => object; f.providers.getCreature = () => null;
    f.providers.aiReaction = () => { assert.fail('Only creatures query reaction'); };
    assert.equal(await addAttackRequest(f.actor, 42, 0, 0, 0, f.providers), 1);
    assert.ok(f.trace.some(v => Array.isArray(v) && v[0] === 'queue'));
    assert.ok(!f.trace.includes('initiative'));
  }
});

test('DM exception, exact-one dead gate and battle-cry divisor preserve native branching', async () => {
  for (const familiar of [false, true]) {
    const { actor, providers, trace } = fixture();
    actor.isPC = false; actor.isPossessedFamiliar = familiar; providers.isDM = () => 1; providers.getDead = () => 2;
    assert.equal(await addAttackRequest(actor, 0, 0, 0, 0, providers), Number(familiar));
    assert.equal(trace.includes('cry'), familiar);
  }
  const f = fixture(); f.actor.nativeField700 = 1;
  assert.equal(await addAttackRequest(f.actor, 0, 0, 0, 0, f.providers), 1);
  assert.equal(f.providers.random.draws, 1); assert.ok(!f.trace.includes('cry'));
});

test('required provider preflight preserves actor, queue and RNG instead of accepting unsupported requests', async () => {
  const { actor, providers, trace } = fixture(), before = structuredClone(actor);
  delete providers.resolveInitiative;
  await assert.rejects(addAttackRequest(actor, 0, 0, 1, 0, providers), /resolveInitiative/);
  assert.deepEqual(actor, before); assert.deepEqual(trace, []); assert.equal(providers.random.draws, 0);
  for (const value of [null, undefined]) {
    const f = fixture(); f.actor.commandable = value;
    await assert.rejects(addAttackRequest(f.actor, 0, 0, 0, 0, f.providers), /AI state/);
    assert.equal(f.providers.random.draws, 0);
  }
  const f = fixture(); f.actor.commandable = false;
  assert.equal(await addAttackRequest(f.actor, 0, 0, 0, 0, f.providers), 0);
});
