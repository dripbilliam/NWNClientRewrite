import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateAttackEligibility } from '../src/attack_eligibility.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function fixture() {
  const area = {}, trace = [];
  const actor = { id: 0x80000001, isPC: true, perceptionUpdateFlags: 255, position: [0, 2, 0],
    attackActionTargetId: OBJECT_INVALID, nativePathInfo: { field8: 0.35, field28: OBJECT_INVALID } };
  const target = { id: 0, isPC: true, position: [1, 2, 0] };
  const providers = { getArea: () => area, getDead: () => 0, getDying: () => 0, getObject: () => target,
    asObject: o => o, asCreature: o => o, visibilityFlags: () => 3,
    maximumRange: () => { trace.push('maximum'); return 2; }, desiredRange: () => { trace.push('desired'); return 0.5; },
    rangedEquipped: () => 0,
    lineOfSight: (a, from, to, actorId, targetId, ranged) => { trace.push(['los', from, to, actorId, targetId, ranged]); return 1; },
    meleeSpatialQuery: (area, from, to, path) => { trace.push(['query', from, to, path.field8, path.field28]); return 1; }
  };
  return { actor, target, providers, area, trace };
}

test('attack actor life/flags/self gates precede target lookup and return distinct native cleanup decisions', async () => {
  for (const gate of ['dead', 'dying', 'flags', 'self']) {
    const f = fixture(); f.providers.getObject = () => assert.fail('Early gate must not resolve target');
    if (gate === 'dead') f.providers.getDead = () => 1;
    if (gate === 'dying') f.providers.getDying = () => 1;
    if (gate === 'flags') f.actor.perceptionUpdateFlags = 0x80;
    const result = await evaluateAttackEligibility(f.actor, gate === 'self' ? f.actor.id : 0, f.providers);
    assert.equal(result.decision, gate === 'self' ? 'clearAnimation' : 'clearTarget');
    assert.equal(f.actor.nativeAttackField748, 6000); assert.equal(result.targetValid, false); assert.deepEqual(f.trace, []);
  }
});

test('missing/dead/imperceived targets pass to round handling without range/LOS queries; dying PCs remain valid', async () => {
  for (const gate of ['missing', 'dead', 'nodeMissing', 'flags']) {
    const f = fixture();
    if (gate === 'missing') f.providers.getObject = () => null;
    if (gate === 'dead') f.providers.getDead = object => Number(object === f.target);
    if (gate === 'nodeMissing') f.providers.visibilityFlags = () => null;
    if (gate === 'flags') f.providers.visibilityFlags = () => 16;
    const result = await evaluateAttackEligibility(f.actor, 0, f.providers);
    assert.equal(result.decision, 'round'); assert.equal(result.targetValid, false); assert.deepEqual(f.trace, []);
  }
  const f = fixture(); f.providers.getDying = object => Number(object === f.target);
  const result = await evaluateAttackEligibility(f.actor, 0, f.providers); assert.equal(result.targetValid, true);
});

test('melee eligibility uses raised LOS endpoints, temporary path overrides and full 3D max-range gate', async () => {
  const f = fixture(), result = await evaluateAttackEligibility(f.actor, 0, f.providers);
  assert.equal(result.decision, 'round'); assert.equal(result.targetId, 0); assert.equal(f.actor.attackActionTargetId, 0);
  assert.deepEqual(f.trace, ['maximum', 'desired', ['los', [0, 3, 0], [1, 3, 0], f.actor.id, 0, 0],
    ['query', [0, 0], [1, 0], Math.fround(0.01), 0]]);
  assert.deepEqual(f.actor.nativePathInfo, { field8: 0.35, field28: OBJECT_INVALID });
  f.target.position = [1, 10, 0]; const far = await evaluateAttackEligibility(f.actor, 0, f.providers);
  assert.equal(far.decision, 'approach'); assert.equal(far.outsideMaximumRange, true);
});

test('blocked LOS, failed spatial query and different areas require approach; ranged skips melee query', async () => {
  for (const gate of ['los', 'melee', 'area']) {
    const f = fixture();
    if (gate === 'los') f.providers.lineOfSight = () => 0;
    if (gate === 'melee') f.providers.meleeSpatialQuery = () => 0;
    if (gate === 'area') f.providers.getArea = object => object === f.actor ? f.area : {};
    const result = await evaluateAttackEligibility(f.actor, 0, f.providers);
    assert.equal(result.decision, 'approach'); assert.equal(result.outsideMaximumRange, gate === 'area');
  }
  const f = fixture(); f.providers.rangedEquipped = () => 1;
  f.providers.meleeSpatialQuery = () => assert.fail('Ranged does not query melee reach');
  assert.equal((await evaluateAttackEligibility(f.actor, 0, f.providers)).decision, 'round');
});

test('unavailable LOS/positions fail explicitly and failing melee queries restore both live path fields', async () => {
  const f = fixture(); delete f.providers.lineOfSight;
  await assert.rejects(evaluateAttackEligibility(f.actor, 0, f.providers), /lineOfSight/);
  f.providers.lineOfSight = () => 1; f.providers.meleeSpatialQuery = () => { throw new Error('geometry failure'); };
  await assert.rejects(evaluateAttackEligibility(f.actor, 0, f.providers), /geometry failure/);
  assert.deepEqual(f.actor.nativePathInfo, { field8: 0.35, field28: OBJECT_INVALID });
  f.target.position = [NaN, 0, 0]; await assert.rejects(evaluateAttackEligibility(f.actor, 0, f.providers), /position/);
});
