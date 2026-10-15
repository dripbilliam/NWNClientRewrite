import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { WorldObjects } from '../src/world_objects.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';
import { createCombatRound } from '../src/combat_round.js';

const session = () => {
  const s = new ModuleSession(null, { runStartupScripts: false });
  s.player = s.register('player', 'pc', { stats: {}, position: [1, 2, 3] });
  s.updateWorldObject = () => {};
  return s;
};
test('NWScript GetIsPC uses attached client ownership independently of authored or stats PC flags',()=>{
  const s=session(),npc=s.register('creature','authored-pc',{isPC:true,nativeStatsIsPCb0:1,stats:{}});
  assert.equal(s.commands.GetIsPC([npc.id]),0);
  s.player.isPC=false;s.player.nativeStatsIsPCb0=0;
  assert.equal(s.commands.GetIsPC([s.player.id]),1);
  assert.equal(s.commands.GetIsPC([0xffffffff]),0);
  s.player.stats=null;assert.equal(s.commands.GetIsPC([s.player.id]),0);
});
test('player Attack is serialized before AI and retains unsigned target IDs and native request flags', async () => {
  const s = session(), trace = [];
  s.player.combatRound = createCombatRound();
  s.combat.requestAttack = (...args) => { trace.push(args); return 0; };
  s.updateWorldObject = () => trace.push('AI');
  const input = s.queuePlayerAttack(0x80000001);
  assert.deepEqual(trace, []);
  await s.scheduler.pump(); assert.equal(await input, 1);
  assert.deepEqual(trace, [[s.player, 0x80000001, 0, 1, 0], 'AI']);
});
test('input arriving during an awaited request waits for the next pump; a failed request does not lose later clicks', async () => {
  const s = session(), trace = []; let unblock, entered;
  const gate = new Promise(resolve => { unblock = resolve; }), start = new Promise(resolve => { entered = resolve; });
  s.combat.receiveAttackInput = async id => { trace.push(id); if (id === 1) { entered(); await gate; throw new Error('Unmapped owner'); } return 1; };
  const first = s.queuePlayerAttack(1), failed = assert.rejects(first, /Unmapped owner/);
  const second = s.queuePlayerAttack(2), pump = s.scheduler.pump(); await start;
  const third = s.queuePlayerAttack(3); await s.scheduler.pump(); assert.deepEqual(trace, [1]);
  unblock(); await pump; await failed; assert.equal(await second, 1); assert.deepEqual(trace, [1, 2]);
  await s.scheduler.pump(); assert.equal(await third, 1); assert.deepEqual(trace, [1, 2, 3]);
  assert.ok(runtimeDiagnostics.records.some(r => r.context.operation === 'queued-player-attack' && r.message === 'Unmapped owner'));
});
test('queued attacks cannot transfer to a changed controlled object, even with a reused canonical ID', async () => {
  const s = session(), original = s.player, input = s.queuePlayerAttack(1);
  s.player = { ...original }; s.combat.receiveAttackInput = () => assert.fail('Stale click transferred');
  await s.scheduler.pump(); assert.equal(await input, 0);
  await assert.rejects(s.queuePlayerAttack(-1), /OBJECT_ID/);
  await assert.rejects(s.queuePlayerAttack(1), /controlled creature/);
});
test('closing a local session settles pending attack requests without delivering them', async () => {
  const s=session(), input=s.queuePlayerAttack(0x80000001);
  s.combat.receiveAttackInput=()=>assert.fail('Closed session input delivered');
  s.cancelPendingPlayerInputs(); assert.equal(await input,0); await s.scheduler.pump();
  assert.equal(s.pendingPlayerInputs.length,0);
});
test('creature render bindings follow canonical position in place, skip other areas/stale registry entries, and never own gameplay state', () => {
  const s = session(), area = s.register('area', 'area', {}), view = new WorldObjects(area.id, s.registry);
  const render = { userData: {}, position: { x: 1, y: 2, z: 3, set(x, y, z) { Object.assign(this, { x, y, z }); } }, rotation: { y: 0.8 } };
  view.add('player', 'pc', s.player, render); const positions = s.player.position, shifts = [];
  s.player.position.splice(0, 3, 4, 2.5, -8);
  view.syncCreaturePositions((actor, delta) => shifts.push([actor.id, delta]));
  assert.equal(s.player.position, positions); assert.deepEqual(shifts, [[s.player.id, [3, 0.5, -11]]]);
  assert.equal(render.rotation.y, 0.8); assert.equal(s.player.renderObject, undefined);
  view.syncCreaturePositions(() => assert.fail('Repeated unchanged position'));
  s.player.areaId = 0xffffffff; s.player.position[0] = 100; view.syncCreaturePositions(); assert.equal(render.position.x, 4);
  s.player.areaId = area.id; view.objects.set(s.player.id, { ...s.player }); view.syncCreaturePositions(); assert.equal(render.position.x, 4);
});
