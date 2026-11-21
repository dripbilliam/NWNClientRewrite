import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound, addCircleKickAttack, addCleaveAttack } from '../src/combat_round.js';
import { resolveMeleeSpecialAttack } from '../src/combat_special_melee.js';
import { ModuleSession } from '../src/module_session.js';

test('Circle Kick and Cleave insert before the rescaled head with native durations, follow flag and ushort queue sequence', () => {
  for (const [count, expected] of [[0,625],[1,625],[2,800],[3,916],[4,857],[5,750],[6,666],[49,115],[50,113],[256,333],[257,625],[-1,625]]) {
    const r = createCombatRound(); Object.assign(r, { started: true, length: 6000, timer: 3000, onhandAttacks: count });
    const head = { time: 3000 }; r.actions.push(head); r.specialAttacks.push(65002); r.specialAttackParameters.push(5); r.specialAttackSequence = 65534;
    addCircleKickAttack(r, 0x80000001);
    assert.equal(r.actions[0].duration, expected, `Native duration for signed total ${count}`);
    assert.equal(r.actions[1], head); assert.equal(r.actions[0].time, 0); assert.equal(r.actions[0].count, 1);
    assert.equal(r.actions[0].followTarget, 1); assert.equal(r.actions[0].animation, 9); assert.equal(r.actions[0].targetId, 0x80000001);
    assert.equal(r.additionalAttacks, 1); assert.equal(r.length, 6000-expected);
    assert.deepEqual(r.specialAttacks, [409,65002]); assert.deepEqual(r.specialAttackParameters, [0,5]); assert.equal(r.specialAttackSequence, 1);
  }
});
test('Cleave inserts during an idle round, and Great Cleave is selected only by exact flag1', () => {
  for (const [great, feat] of [[0,6],[1,391],[2,6],[-1,6]]) {
    const r = createCombatRound(); addCleaveAttack(r, 0xffffffff, great);
    assert.equal(r.length, 0); assert.equal(r.actions.length, 1); assert.equal(r.actions[0].duration, 625);
    assert.equal(r.actions[0].targetId, 0xffffffff); assert.equal(r.additionalAttacks, 1); assert.deepEqual(r.specialAttacks, [feat]);
  }
});
function special(type, uses=100, result=1) {
  const a = { combatRound: createCombatRound() }, t = {}, trace = [], record = a.combatRound.attacks[0]; record.attackType = type;
  const p = { asCreature:o=>{trace.push('cast');return o;}, remainingUses:(o,id)=>{trace.push(['uses',id]);return uses;},
    attackRoll:()=>{trace.push('roll');record.result=result;},damage:()=>trace.push('damage'),postDamage:()=>trace.push('post'),
    animations:()=>trace.push('animation'), specialEffect:()=>trace.push('extra') };
  return {a,t,p,trace,record};
}
test('native melee special common owner handles Cleave, Circle Kick and default IDs without fabricated feat effects', async () => {
  for (const type of [6,391,409,65002,65003,1115,1116,65535]) {
    const f = special(type); await resolveMeleeSpecialAttack(f.a,0,1,f.t,625,f.p);
    assert.deepEqual(f.trace, ['cast','cast',...(type<1116?[['uses',type]]:[]),'roll','damage','post','animation']);
    assert.equal(f.record.attackType,type);
  }
});
test('special remaining-use gate is a BYTE and precedes the roll; post-resolution effect dispatch rereads the record', async () => {
  const empty = special(31,256); await resolveMeleeSpecialAttack(empty.a,0,1,empty.t,625,empty.p);
  assert.equal(empty.record.attackType,0); assert.equal(empty.trace.includes('extra'),false);
  const changed = special(6); changed.p.postDamage=()=>{changed.trace.push('post');changed.record.attackType=31;};
  await resolveMeleeSpecialAttack(changed.a,0,1,changed.t,625,changed.p); assert.deepEqual(changed.trace.slice(-3),['post','animation','extra']);
  const missed = special(409,100,4); await resolveMeleeSpecialAttack(missed.a,0,1,missed.t,625,missed.p);
  assert.deepEqual(missed.trace,['cast','cast',['uses',409],'roll','animation']);
});
test('unimplemented special effects fail explicitly after the shared native roll/damage/animation path', async () => {
  const f=special(31); delete f.p.specialEffect;
  await assert.rejects(resolveMeleeSpecialAttack(f.a,0,1,f.t,625,f.p),/specialEffect is unavailable/);
  assert.deepEqual(f.trace.slice(-4),['roll','damage','post','animation']);
});
test('live damage providers use the shared follow-up insertion owners', () => {
  const s=new ModuleSession(null), actor={id:1}, p=s.combat.damageStageProviders(actor);
  const kick=createCombatRound();p.circleKick(kick,0x80000001);assert.deepEqual(kick.specialAttacks,[409]);
  const cleave=createCombatRound();p.cleave(cleave,0x80000002,1);assert.deepEqual(cleave.specialAttacks,[391]);
});
