import test from 'node:test';
import assert from 'node:assert/strict';
import {updateCreaturePerception,updateVisibleList} from '../src/perception_detection.js';
import {receivePerceptionEvent} from '../src/perception_events.js';
import {loadPerceptionRanges,postProcessPerceptionRanges} from '../src/perception_ranges.js';
import {clearHostileActionsVersus} from '../src/combat_hostile.js';
import {createObjectActionState,addObjectAction,removeObjectActionGroup} from '../src/object_actions.js';
import {VisibilityList} from '../src/perception.js';
import {NativeAreaSpatialArray} from '../src/area_spatial.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const invalid=0x7f000000;
function fixture(){
  const base={position:[0,0,0],nativeField700:0,nativeSightRange7b0:10,nativeCombatSightRange7b4:20,nativeHearingRange7b8:10,nativeCombatHearingRange7bc:20,
    nativeStatsFieldBC:0,nativeCollisionFlag788:0,visionFlags:0,nativeSilence75c:0,associateType:0};
  const actor={...base,id:1,perception:new VisibilityList(1)},target={...base,id:2,position:[3,0,0]},area={id:3},calls=[];
  const result={seen:1,heard:1},p={area:()=>area,hasFeat:()=>0,dm:()=>0,invisibleCreatureIds:()=>[],creature:id=>id===target.id?target:null,
    lineOfSight:()=>1,invisible:()=>1,stealthDetection:(a,t,c,out,r)=>{calls.push(['detect',c,r]);Object.assign(out,result);},
    clearHostileActions:(a,t)=>calls.push(['clear',a.perception.get(t.id)]),enqueue:(...args)=>calls.push(['event',...args])};
  return{actor,target,area,calls,result,p};
}
const codes=calls=>calls.filter(c=>c[0]==='event').map(c=>c[5].integers[0]);
test('visibility adds a native node and hears before seeing; stable seen+heard skips detection',async()=>{
  const {actor,target,p,calls}=fixture();await updateCreaturePerception(actor,target,0,p);
  assert.equal(actor.perception.get(target.id),3);assert.deepEqual(codes(calls),[0,2]);
  for(const c of calls.filter(c=>c[0]==='event'))assert.deepEqual(c.slice(1,5),[10,2,1,0]);
  calls.length=0;await updateCreaturePerception(actor,target,0,p);assert.deepEqual(calls,[]);
});
test('visibility existing node gains sight before hearing and preserves upper state bits',async()=>{
  const {actor,target,p,calls}=fixture();actor.perception.set(target.id,0xc0);
  await updateCreaturePerception(actor,target,0,p);assert.equal(actor.perception.get(target.id),0xc3);assert.deepEqual(codes(calls),[2,0]);
});
test('visibility loss clears hearing before sight, removes empty node, and suppresses Spot at strict max-range boundary',async()=>{
  const {actor,target,p,calls,result}=fixture();actor.perception.set(target.id,3);target.position=[10,0,0];result.seen=result.heard=0;
  let rays=0;p.lineOfSight=()=>{rays++;return 1;};await updateCreaturePerception(actor,target,0,p);
  assert.equal(rays,0);assert.deepEqual(calls[0],['detect',0,0]);assert.deepEqual(codes(calls),[1,3]);assert.equal(actor.perception.get(target.id),undefined);
});
test('invisibility list is distinct from PCs and cancellation occurs before retained flag changes',async()=>{
  const {actor,target,p,calls}=fixture();actor.perception.set(target.id,3);p.invisibleCreatureIds=()=>[target.id];
  await updateCreaturePerception(actor,target,0,p);
  assert.deepEqual(calls,[['clear',3],['event',10,2,1,0,{type:1,integers:[3],objectIds:[2]}]]);
  assert.equal(actor.perception.get(target.id),18); // retained + heard.
  calls.length=0;p.invisibleCreatureIds=()=>[];await updateCreaturePerception(actor,target,0,p);
  assert.deepEqual(codes(calls),[2]);assert.equal(actor.perception.get(target.id),3);
});
test('forced Hide in Plain Sight rechecks stable node and clears hostile actions on sight loss',async()=>{
  const {actor,target,p,calls,result}=fixture();actor.perception.set(target.id,3);result.seen=result.heard=0;
  await updateCreaturePerception(actor,target,1,p);assert.deepEqual(calls,[]);
  p.hasFeat=(o,id)=>{assert.equal(o,target);assert.equal(id,433);return 1;};
  await updateCreaturePerception(actor,target,1,p);assert.deepEqual(calls.slice(0,2),[['detect',1,0],['clear',3]]);
  assert.deepEqual(codes(calls),[1,3]);assert.equal(actor.perception.get(target.id),undefined);
});
test('perception event slots remain independent and PC default script veto follows cache updates',async()=>{
  const actor={},calls=[],p={scriptName:()=> 'default',pc:()=>1,runScript:(...args)=>calls.push(args)};
  for(const [code,fields] of [[0,[1,0,0,0]],[1,[0,0,1,0]],[2,[0,1,0,0]],[3,[0,0,0,1]]]){
    await receivePerceptionEvent(actor,{type:1,integers:[code],objectIds:[0x80000002]},p);
    assert.equal(actor.nativeLastPerceived79c,0x80000002);
    assert.deepEqual([actor.nativePerceptionHeard7a0,actor.nativePerceptionSeen7a4,actor.nativePerceptionInaudible7a8,actor.nativePerceptionVanished7ac],fields);
  }
  assert.deepEqual(calls,[]);p.pc=()=>0;await receivePerceptionEvent(actor,{type:1,integers:[9],objectIds:[3]},p);
  assert.deepEqual(calls,[[actor,1]]);assert.equal(actor.nativePerceptionVanished7ac,1);
});
test('active range table uses physical rows and appearance lookup, with exact NPC rejection and partial writes',()=>{
  const rows=Array.from({length:14},(_,i)=>`${99-i} ${i} ${i+1}`);
  const rules={ranges:parse2da(`2DA V2.0\n\nPrimaryRange SecondaryRange\n${rows.join('\n')}`),appearance:parse2da('2DA V2.0\n\nPERCEPTIONDIST\n88 2')};
  const actor={creatureData:{IsPC:0,Appearance_Type:0},visionFlags:0,nativeField700:0};
  loadPerceptionRanges(actor,rules);assert.equal(actor.nativeSightRange7b0,2);assert.equal(actor.nativeHearingRange7b8,3);
  postProcessPerceptionRanges(actor,rules,{pc:()=>0,possessed:()=>0,hasFeat:()=>0});
  assert.equal(actor.nativeCombatSightRange7b4,13);assert.equal(actor.nativeCombatHearingRange7bc,14);
  actor.creatureData.IsPC=1;actor.creatureData.PerceptionRange=0;loadPerceptionRanges(actor,rules);
  assert.equal(actor.nativeSightRange7b0,12);assert.equal(actor.nativePerceptionRange798,11);
  actor.creatureData.IsPC=0;actor.creatureData.PerceptionRange=12;assert.throws(()=>loadPerceptionRanges(actor,rules),/rejects/);
  actor.creatureData.PerceptionRange=1;rules.ranges.orderedRows[1].SecondaryRange='****';assert.throws(()=>loadPerceptionRanges(actor,rules),/SecondaryRange/);
  assert.equal(actor.nativeSightRange7b0,1);assert.equal(actor.nativeHearingRange7b8,13);
});
test('blindsight native fallback values and priority are retained, with ruleset override capped by combat sight',()=>{
  const rows=Array.from({length:14},(_,i)=>`${i} 20 25`),rules={ranges:parse2da(`2DA V2.0\n\nPrimaryRange SecondaryRange\n${rows.join('\n')}`)};
  for(const [feat,expected] of [[488,Math.fround(18.288)],[486,4],[485,2]]){
    const actor={visionFlags:0},calls=[];
    postProcessPerceptionRanges(actor,rules,{pc:()=>1,possessed:()=>0,hasFeat:(o,id)=>{calls.push(id);return Number(id===feat);}});
    assert.equal(actor.blindSightRange,expected);assert.equal(actor.visionFlags,32);assert.equal(calls.at(-1),feat);
  }
  rules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 BLINDSIGHT_RANGE_60_FEET 100');const actor={visionFlags:4};
  postProcessPerceptionRanges(actor,rules,{pc:()=>1,hasFeat:()=>1});assert.equal(actor.blindSightRange,20);assert.equal(actor.visionFlags,36);
});
test('hostile group clearing preserves native restart-at-one quirk and cancellation vetoes',async()=>{
  const actor={objectActionState:createObjectActionState()},target={id:8},state=actor.objectActionState;
  const first=addObjectAction(state,12,1,[{type:3,value:8}]),second=addObjectAction(state,12,2,[{type:3,value:8}]),third=addObjectAction(state,12,3,[{type:3,value:8}]);
  const cleared=[];await clearHostileActionsVersus(actor,target,{removeGroup:(a,id)=>removeObjectActionGroup(a,id,{clearAction:(o,n,h)=>{cleared.push([n,h]);return 1;}})});
  assert.deepEqual([...state.list],[second]);assert.deepEqual(cleared,[[first,true],[third,false]]);
  addObjectAction(state,12,4,[{type:3,value:8}]);await removeObjectActionGroup(actor,2,{clearAction:()=>0});assert.equal(state.list.count,2);
});
test('visible list updates cached entries in reverse, removes stale IDs, then visits new native X candidates only once',async()=>{
  const {actor,target,p,calls,area}=fixture(),left={...target,id:4,position:[-2,0,0]},far={...target,id:5,position:[11,0,0]};
  const objects=new Map([[1,actor],[2,target],[4,left],[5,far]]),spatial=new NativeAreaSpatialArray({get:id=>objects.get(id)});
  for(const id of [1,2,4,5])spatial.insert(id);actor.perception.set(2,3);actor.perception.set(99,3);
  p.creature=id=>objects.get(id)??null;p.dead=()=>0;p.pc=()=>0;p.spatial=()=>spatial;p.markPerceptionWork=()=>calls.push('mark');
  p.updatePerception=(a,t)=>{calls.push(t.id);a.perception.set(t.id,3);};
  await updateVisibleList(actor,p);assert.deepEqual(calls,['mark',2,4]);assert.equal(actor.perception.node(99),null);
});
test('live perception dispatch updates NWScript accessors with canonical unsigned target ID',async()=>{
  const s=new ModuleSession({},{}),actor=s.register('creature','observer',{}),target=s.register('creature','target',{});
  await s.combat.dispatchEvent(actor,{eventId:10,payload:{type:1,integers:[2],objectIds:[target.id]}});
  assert.equal(s.commands.GetLastPerceived([],{self:actor.id}),target.id);assert.equal(s.commands.GetLastPerceptionSeen([],{self:actor.id}),1);
  assert.equal(s.commands.GetLastPerceptionHeard([],{self:actor.id}),0);assert.equal(s.commands.GetLastPerceptionVanished([],{self:actor.id}),0);
  assert.equal(s.commands.GetLastPerceived([],{self:invalid}),invalid);
});
