import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { parse2da } from '../src/area.js';
import { createCombatRound } from '../src/combat_round.js';
import { NativeRandom } from '../src/native_random.js';
import { actionParameter, addObjectAction } from '../src/object_actions.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { executeWait } from '../src/movement_actions.js';
import { NativeAreaSpatialArray } from '../src/area_spatial.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';

function fixture() {
  const session = new ModuleSession(null, { runStartupScripts: false });
  session.characterRules = { appearance: parse2da('2DA V2.0\n\nMODELTYPE PREFATCKDIST HITDIST weaponscale\n0 P 1 0.5 1') };
  const area = session.register('area', 'area', { objects: [] });
  const create = (kind, id) => session.register(kind, id, { areaId: area.id, commandable: true,
    isPC: kind === 'player', position: [0, 0, 0], inventory: [], scripts: {}, authored: { Appearance_Type: 0 },
    creatureData: { Appearance_Type: 0 }, modelType: 'P', combatRound: createCombatRound(),
    stats: { currentHP: 30, maxHP: 30, feats: [], equippedAbilities: { Dex: 10 } } });
  const pc = create('player', 'player'), npc = create('creature', 'npc'); session.player = pc;
  session.random = new NativeRandom(1); return { session, pc, npc };
}

test('session native request uses canonical live action storage and existing initiative RNG; world timing retains the record', async () => {
  const { session, pc, npc } = fixture(), trace = []; pc.initiativePending = 1;
  const providers = { feedback: () => assert.fail(), aiReaction: () => 0, clearActions: () => trace.push('clear'),
    actionManager: (actor, action) => trace.push(['manager', action]),
    broadcastAssociateCommand: () => assert.fail(), broadcastBattleCry: () => trace.push('cry'),
    broadcastCombatState: () => trace.push('state'), doorFieldFC: () => assert.fail(), enqueueDoorEvent: () => assert.fail() };
  assert.equal(await session.combat.requestAttack(pc, npc.id, 0, 0, 0, providers), 1);
  const state = pc.objectActionState, node = state.list.head.action;
  assert.equal(node.actionId, 12); assert.equal(node.groupId, 0); assert.equal(actionParameter(node, 0), npc.id);
  assert.equal(pc.attackActionTargetId, npc.id); assert.equal(session.registry.get(pc.id), pc);
  assert.equal(session.random.draws, 2); assert.equal(pc.initiativeRoll, 8);
  assert.deepEqual(trace, [['manager', 4], 'state']);
  session.scheduler.advance(1000); await session.scheduler.pump();
  assert.equal(pc.objectActionState, state); assert.equal(state.list.head.action, node);
  assert.equal(session.hitPoints(pc.id, false), 30); assert.equal(session.random.draws, 2);
  // RecomputeAIState sees the queued attack: duplicate request skips RNG.
  assert.equal(await session.combat.requestAttack(pc, npc.id, 0, 1, 0, providers), 1);
  assert.equal(state.list.count, 1); assert.equal(pc.currentAITargetId, npc.id); assert.equal(session.random.draws, 2);
});

test('session eligibility reads shared seen/heard cache and active range rules; absent geometry is diagnosed with canonical context', async () => {
  const { session, pc, npc } = fixture(); npc.position[0] = 1;
  assert.equal((await session.combat.evaluateAttack(pc, npc.id)).targetValid, false);
  pc.perception.set(npc.id, 3); assert.equal(session.commands.GetObjectSeen([npc.id, pc.id]), 1);
  assert.equal(session.commands.GetObjectHeard([npc.id, pc.id]), 1);
  const before = runtimeDiagnostics.records.length;
  await assert.rejects(session.combat.evaluateAttack(pc, npc.id), /lineOfSight/);
  assert.ok(session.diagnostics.some(message => message.includes('lineOfSight')));
  assert.ok(runtimeDiagnostics.records.slice(before).some(record => record.context?.objectId === pc.id));
  pc.nativePathInfo = { field8: 0.35, field28: 123 };
  const result = await session.combat.evaluateAttack(pc, npc.id, { lineOfSight: () => 1, meleeSpatialQuery: () => 1 });
  assert.equal(result.decision, 'round'); assert.equal(result.desired, 1.5); assert.equal(result.maximum, 3);
  assert.equal(result.targetId, npc.id); assert.equal(session.hitPoints(npc.id, false), 30);
  assert.equal(session.random.draws, 0); assert.deepEqual(pc.nativePathInfo, { field8: 0.35, field28: 123 });
});

test('canonical creature field708 aliases passive/changed state and script attack target reads724 rather than738',()=>{
  const {session,pc,npc}=fixture();pc.passiveAttack=1;assert.equal(pc.attackTargetChanged,1);assert.equal(pc.nativeField708,1);
  pc.attackTargetChanged=0;assert.equal(pc.passiveAttack,0);
  pc.nativeAttackTarget724=npc.id;pc.attackTargetId=123;assert.equal(session.commands.GetAttackTarget([pc.id]),npc.id);
  assert.equal(session.commands.GetAttackTarget([invalid]),invalid);
  const o=session.register('creature','raw708',{nativeField708:7});assert.equal(o.attackTargetChanged,7);assert.equal(o.passiveAttack,7);
  assert.throws(()=>session.register('creature','conflict',{nativeField708:1,passiveAttack:0}),/Conflicting/);
});
test('native field8d4 word and perception byte share storage, preserving upper byte and detecting contradictory imports',()=>{
  const {session,pc}=fixture();assert.equal(pc.nativeMovementFlags8d4,65535);pc.nativeMovementFlags8d4&=0xfffd;assert.equal(pc.perceptionUpdateFlags,253);
  pc.perceptionUpdateFlags=132;assert.equal(pc.nativeField8d4,0xff84);assert.equal(pc.nativeMovementFlags8d4,0xff84);
  assert.equal(pc.nativeDeathWord8d4,0xff84);pc.nativeDeathWord8d4=0;
  assert.equal(pc.nativeField8d4,0);assert.equal(pc.nativeMovementFlags8d4,0);assert.equal(pc.perceptionUpdateFlags,0);
  assert.throws(()=>session.register('creature','bad8d4',{nativeMovementFlags8d4:0xfffd,perceptionUpdateFlags:255}),/Conflicting/);
});

test('live native replacement query uses canonical ordered storage and native radius/LOS providers',async()=>{
  const {session,pc,npc}=fixture(),area=session.registry.get(pc.areaId);npc.position=[2,0,0];
  area.nativeSpatial=new NativeAreaSpatialArray(session.registry);area.nativeSpatial.insert(pc.id);area.nativeSpatial.insert(npc.id);
  pc.perception.set(npc.id,1);
  assert.equal(await session.combat.newTarget(pc,invalid,{reaction:()=>2,lineOfSight:()=>1,creatureLine:()=>1}),npc);
  assert.equal(await session.combat.newTarget(pc,npc.id,{reaction:()=>2,lineOfSight:()=>1,creatureLine:()=>1}),null);
  pc.perception.set(npc.id,2);assert.equal(await session.combat.newTarget(pc,invalid,{reaction:()=>2}),null);
});

const bits=value=>{const raw=new DataView(new ArrayBuffer(4));raw.setFloat32(0,value,true);return raw.getInt32(0,true);};
test('live action19 faces canonical targets without clearing paths; action49 uses native XY, action4 owns the path reset',async()=>{
  const {session,pc,npc}=fixture(),path=pc.nativePathInfo;
  pc.position=[1,2,-2];npc.position=[4,100,-6];
  const route=new Float32Array([1,2,3,4]);path.allocations.set(0x80,route);
  const run=()=>session.combat.runActions(pc,1,100,0n,{microseconds:()=>0n});
  addObjectAction(pc.objectActionState,19,7,[{type:3,value:npc.id}]);await run();
  assert.deepEqual(pc.orientation,[Math.fround(.6),0,Math.fround(-.8)]);
  assert.equal(path.allocations.get(0x80),route);assert.equal(pc.objectActionState.list.count,0);
  addObjectAction(pc.objectActionState,49,7,[{type:2,value:bits(-2)},{type:2,value:bits(-2)},{type:2,value:bits(-100)}]);await run();
  assert.deepEqual(pc.orientation,[Math.fround(-.6),0,Math.fround(.8)]);
  assert.equal(path.allocations.get(0x80),route);
  addObjectAction(pc.objectActionState,4,7,[]);
  await session.combat.runActions(pc,1,100,0n,{microseconds:()=>1001n});
  assert.equal(path.allocations.has(0x80),false);assert.equal(pc.objectActionState.list.head.action.actionId,30);
  assert.equal(actionParameter(pc.objectActionState.list.head.action,0),.75);
});
test('live facing uses trigger polygon center/area height and preserves unavailable geometry with diagnostics',async()=>{
  const {session,pc}=fixture(),area=session.registry.get(pc.areaId);pc.position=[1,2,-2];
  const trigger=session.register('trigger','trigger',{areaId:area.id,position:[100,100,100],geometry:[[0,0],[8,0],[8,12],[0,12]]});
  const heightPoints=[];area.nativeGeometry={height:async point=>{heightPoints.push([...point]);return 300;}};
  addObjectAction(pc.objectActionState,19,7,[{type:3,value:trigger.id}]);
  await session.combat.runActions(pc,1,100,0n,{microseconds:()=>0n});
  assert.deepEqual(heightPoints,[[4,6,0]]);assert.deepEqual(trigger.nativeFacingBounds,[0,8,0,12]);
  assert.deepEqual(pc.orientation,[Math.fround(.6),0,Math.fround(-.8)]);
  trigger.nativeFacingBounds.fill(0);trigger.geometry=[];
  const node=addObjectAction(pc.objectActionState,19,7,[{type:3,value:trigger.id}]);
  await assert.rejects(session.combat.runActions(pc,1,100,0n,{microseconds:()=>0n}),/no first vertex/);
  assert.equal(pc.objectActionState.list.head.action,node);
  assert.ok(session.diagnostics.some(message=>message.includes('no first vertex')));
});
test('live cast wait retains an active round but releases for any due spell; future spells do not release it',async()=>{
  const {session,pc}=fixture(),round=pc.combatRound;round.started=true;round.timer=100;
  const node=addObjectAction(pc.objectActionState,16,7,[]),run=()=>session.combat.runActions(pc,1,100,0n,{microseconds:()=>0n});
  round.actions=[{nativeActionType:1,time:0},{nativeActionType:2,time:101}];await run();
  assert.equal(pc.objectActionState.list.head.action,node);
  round.actions[1].time=100;await run();assert.equal(pc.objectActionState.list.count,0);
});
test('native wait supports live dispatch, strict boundary, unsigned duration and day remainder quirks',async()=>{
  const {session,pc}=fixture(),state=pc.objectActionState;
  const wait=seconds=>addObjectAction(state,30,7,[{type:2,value:bits(seconds)}]);
  const node=wait(.75);state.startDay=1;state.startTime=100;
  const p={dead:()=>0,dying:()=>0,worldTime:()=>({day:1,time:849}),dayLength:10000};
  assert.equal(await executeWait(pc,node,p),1);p.worldTime=()=>({day:1,time:850});assert.equal(await executeWait(pc,node,p),2);
  p.worldTime=()=>({day:2,time:101});assert.equal(await executeWait(pc,node,p),1); // ignores elapsed day count
  const negative=wait(-1);assert.equal(await executeWait(pc,negative,p),1);const nan=wait(NaN);assert.equal(await executeWait(pc,nan,p),2);
  p.dead=()=>2;assert.equal(await executeWait(pc,node,p),1);p.dead=()=>1;assert.equal(await executeWait(pc,node,p),3);
  p.dead=()=>0;p.worldTime=()=>({day:1,time:99});await assert.rejects(executeWait(pc,node,p),/uninitialized/);
  // Dispatch uses the same shared world clock; zero duration completes at once.
  state.list.head=state.list.tail=null;state.list.count=0;state.startDay=state.startTime=0;wait(0);
  const now=session.worldTimer.time();await session.combat.runActions(pc,now.day,now.time,0n,{microseconds:()=>0n});assert.equal(state.list.count,0);
});
