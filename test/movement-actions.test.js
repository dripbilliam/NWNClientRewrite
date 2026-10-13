import test from 'node:test';
import assert from 'node:assert/strict';
import { addMoveToPointFront, queueAttackApproach, checkMoveRadius, checkInterArea, addPathfindingWaitFront } from '../src/movement_actions.js';
import { createObjectActionState, addObjectAction, actionParameter } from '../src/object_actions.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(type=5){
  const actor={id:0x80000001,position:[4,2,-6],attackTargetPosition:[0,0,0],attackTargetChanged:0,nativeField948:invalid,
    objectActionState:createObjectActionState(),nativePathInfo:new PathInformation(0x80000001),isPC:true};
  const target={id:0x80000002,objectType:type,nativePathInfo:new PathInformation(0x80000002)};
  const node=addObjectAction(actor.objectActionState,12,8,[{type:3,value:target.id}]);
  actor.objectActionState.list.shift(); // RunActions has removed executing node.
  const e={targetId:target.id,targetPosition:[10,3,-11],targetArea:{id:0x80000003},desired:1.5,maximum:3,spatialResult:1,outsideMaximumRange:true};
  const trace=[],p={object:()=>target,setLock:(o,id)=>trace.push(['lock',id]),newTarget:()=>null,
    changeTarget:(o,n,id)=>trace.push(['target',id]),feedback:(o,code)=>trace.push(['feedback',code]),ranged:()=>0};
  return{actor,target,node,e,p,trace};
}

test('pathfinding wait uses actual client lookup rather than actor PC flag',async()=>{
  const {actor}=fixture();await addPathfindingWaitFront(actor,8,{client:()=>null});
  assert.equal(actionParameter(actor.objectActionState.list.head.action,0),Math.fround(.3));
  actor.isPC=false;await addPathfindingWaitFront(actor,8,{client:()=>({})});assert.equal(actionParameter(actor.objectActionState.list.head.action,0),Math.fround(.1));
});
test('radius check completes inside native use range; blocked LOS tightens stop distance and queues wait/move/check',async()=>{
  const {actor,target,p}=fixture();target.position=[5,2,-6];target.areaId=3;actor.position=[4,2,-6];const area={id:3};
  const node=addObjectAction(actor.objectActionState,17,8,[{type:3,value:target.id},{type:1,value:1},{type:2,value:bits(2)},{type:2,value:bits(3)},{type:1,value:1}]);
  actor.objectActionState.list.shift();
  const providers={...p,client:()=>({}),dead:()=>0,dying:()=>0,object:()=>target,asObject:o=>o,asCreature:o=>o,area:()=>area,
    useRange:(a,id,out)=>{out.point=target.position;out.range=1.5;return 1;},inUseRange:(a,id,extra,transparent)=>{assert.equal(extra,Math.fround(Math.fround(3-1.5)-Math.fround(.1)));assert.equal(transparent,0);return 1;},lineOfSight:()=>0};
  assert.equal(await checkMoveRadius(actor,node,providers),2);assert.equal(actor.objectActionState.list.count,0);
  providers.inUseRange=()=>0;assert.equal(await checkMoveRadius(actor,node,providers),2);
  const queued=[...actor.objectActionState.list];assert.deepEqual(queued.map(n=>n.actionId),[30,1,17]);
  assert.equal(actionParameter(queued[1],5),513);assert.equal(actionParameter(queued[1],6),1.5);assert.equal(queued[2].parameterCount,6);
  // Already at minimum summed creature radii: finish rather than endless retry.
  node.parameterData[2]=bits(Math.fround(actor.nativePathInfo.field8+target.nativePathInfo.field8));
  assert.equal(await checkMoveRadius(actor,node,providers),3);
});
const bits=value=>{const raw=new DataView(new ArrayBuffer(4));raw.setFloat32(0,value,true);return raw.getInt32(0,true);};
test('radius-check no-area creature fallback uses stored movement area/goal and retains transparent flag',async()=>{
  const {actor,target,p}=fixture();target.position=[9,0,0];target.nativeMovementAreaId=4;target.nativeMovementGoal=[20,0,-30];const area={id:3},destination={id:4};
  const node=addObjectAction(actor.objectActionState,17,8,[{type:3,value:target.id},{type:1,value:0},{type:2,value:bits(1)},{type:2,value:bits(.5)},{type:1,value:0},{type:1,value:7}]);actor.objectActionState.list.shift();
  assert.equal(await checkMoveRadius(actor,node,{...p,client:()=>null,dead:()=>0,dying:()=>0,asObject:o=>o,asCreature:o=>o,area:o=>o===actor?area:null,
    moduleArea:id=>id===4?destination:null,useRange:(a,id,out)=>{out.range=.6;return 0;}}),2);
  const queued=[...actor.objectActionState.list];assert.deepEqual(Array.from({length:5},(_,i)=>actionParameter(queued[1],i)),[20,30,0,4,target.id]);
  assert.equal(actionParameter(queued[2],3),Math.fround(Math.fround(1)+Math.fround(.01)));assert.equal(actionParameter(queued[2],5),7);
});
test('interarea check resets search only, retains endpoints/range/19c, and inserts native .75 wait',async()=>{
  const {actor,node}=fixture();const path=actor.nativePathInfo;path.raw.setFloat32(0x4c,10,true);path.raw.setFloat32(0x58,2,true);path.field19c=1;
  path.allocations.set(0x80,new Float32Array([0,0,1,1]));
  const p={dead:()=>0,dying:()=>0,area:()=>({})};assert.equal(await checkInterArea(actor,node,p),2);
  assert.equal(path.raw.getFloat32(0x4c,true),10);assert.equal(path.raw.getFloat32(0x58,true),2);assert.equal(path.field19c,1);assert.equal(path.allocations.size,0);
  assert.equal(actionParameter(actor.objectActionState.list.head.action,0),.75);
  p.area=()=>null;assert.equal(await checkInterArea(actor,node,p),1);p.dead=()=>1;assert.equal(await checkInterArea(actor,node,p),3);
});
test('interarea route shift copies native a8 order to both allocations, sets adjusted goal, and preserves queue group',async()=>{
  const {actor,node,p}=fixture(),path=actor.nativePathInfo;path.raw.setInt32(0xa4,3,true);path.allocations.set(0xa8,new Uint32Array([2,3,4]));path.allocations.set(0xb0,new Uint32Array([99,88]));
  const providers={...p,dead:()=>0,dying:()=>0,area:()=>({}),client:()=>null,setIntraAreaGoal:path=>{path.raw.setFloat32(0x4c,20,true);path.raw.setFloat32(0x50,30,true);path.raw.setFloat32(0x54,40,true);path.raw.setUint32(0x60,3,true);}};
  assert.equal(await checkInterArea(actor,node,providers),2);assert.deepEqual([...path.allocations.get(0xa8)],[3,4]);assert.deepEqual([...path.allocations.get(0xb0)],[3]);
  assert.equal(path.raw.getFloat32(0x4c,true),15);assert.equal(path.raw.getInt32(0xa0,true),1);
  const queued=[...actor.objectActionState.list];assert.deepEqual(queued.map(n=>[n.actionId,n.groupId]),[[30,8],[30,8],[1,8]]);
  assert.deepEqual(Array.from({length:5},(_,i)=>actionParameter(queued[2],i)),[20,30,40,3,invalid]);
});
test('native move-front action packs native coordinate float bits, all flag fields and canonical high-bit IDs',async()=>{
  const {actor,p,trace}=fixture();
  assert.equal(await addMoveToPointFront(actor,7,[4,2,-6],0x80000003,0x80000002,1,1.5,0.25,1,23,5,2,1,1,p),1);
  const node=actor.objectActionState.list.head.action;
  assert.equal(node.actionId,1);assert.equal(node.parameterCount,9);assert.equal(node.groupId,7);
  assert.deepEqual([...node.parameterTypes].slice(0,9),[2,2,2,3,3,1,2,1,2]);
  assert.deepEqual(Array.from({length:9},(_,i)=>actionParameter(node,i)),[4,6,2,0x80000003,0x80000002,863,1.5,23,0.25]);
  assert.deepEqual(trace,[['lock',invalid]]);
});
test('native combat approach replaces executing attack with ordered move1/interarea19/radius17/attack12 in the same group',async()=>{
  const {actor,target,node,e,p,trace}=fixture();
  assert.equal(await queueAttackApproach(actor,node,e,p),2);
  const actions=[...actor.objectActionState.list];
  assert.deepEqual(actions.map(n=>n.actionId),[1,19,17,12]);assert.deepEqual(actions.map(n=>n.groupId),[8,8,8,8]);
  assert.deepEqual(actor.attackTargetPosition,actor.position);assert.notEqual(actor.attackTargetPosition,actor.position);
  assert.deepEqual(Array.from({length:9},(_,i)=>actionParameter(actions[0],i)),[10,11,3,e.targetArea.id,target.id,1,1.5,0,0]);
  assert.deepEqual(Array.from({length:5},(_,i)=>actionParameter(actions[2],i)),[target.id,1,1.5,3,1]);
  assert.equal(actionParameter(actions[1],0),target.id);assert.equal(actionParameter(actions[3],0),target.id);
  assert.deepEqual(trace,[['lock',invalid]]);assert.equal(actor.nativePathInfo.field19c,0);
});
test('blocked same-area approach changes stop distance to summed native creature radii and sets path19c',async()=>{
  const t=fixture();t.e.spatialResult=0;t.e.outsideMaximumRange=false;t.target.nativePathInfo.field8=0.2;
  await queueAttackApproach(t.actor,t.node,t.e,t.p);
  assert.equal(actionParameter(t.actor.objectActionState.list.head.action,6),Math.fround(Math.fround(0.6)+Math.fround(0.2)));
  assert.equal(t.actor.nativePathInfo.field19c,1);
});
test('blocked noncreature uses path radius4; door move ignores tracking ID while checks retain canonical door ID',async()=>{
  const t=fixture(10);t.e.spatialResult=0;t.e.outsideMaximumRange=false;
  t.actor.nativePathInfo.raw.setFloat32(4,0.3,true);
  await queueAttackApproach(t.actor,t.node,t.e,t.p);
  const actions=[...t.actor.objectActionState.list];
  assert.equal(actionParameter(actions[0],4),invalid);assert.equal(actionParameter(actions[0],6),Math.fround(0.3));
  assert.equal(actionParameter(actions[1],0),t.target.id);assert.equal(actionParameter(actions[2],0),t.target.id);
});
test('unchanged PC approach reports218 then searches a new melee target or clears; ranged skips search',async()=>{
  for(const ranged of [0,1]){
    const t=fixture();t.actor.attackTargetPosition=[...t.actor.position];t.p.ranged=()=>ranged;
    t.p.newTarget=()=>{t.trace.push('search');return null;};
    assert.equal(await queueAttackApproach(t.actor,t.node,t.e,t.p),3);
    assert.deepEqual(t.trace,ranged?[['feedback',218],['target',invalid]]:[['feedback',218],'search',['target',invalid]]);
    assert.equal(t.actor.objectActionState.list.count,0);
  }
});
test('approach retarget flag selects canonical replacement without inserting movement actions',async()=>{
  const t=fixture();t.actor.attackTargetChanged=1;t.p.newTarget=()=>({id:0x80000009});
  assert.equal(await queueAttackApproach(t.actor,t.node,t.e,t.p),1);
  assert.deepEqual(t.trace,[['target',0x80000009]]);assert.equal(t.actor.objectActionState.list.count,0);
});
test('target with no area uses saved native movement goal for creature; unavailable retarget owner leaves executing action intact',async()=>{
  const t=fixture();t.e.targetArea=null;t.target.nativeMovementAreaId=0x80000004;t.target.nativeMovementGoal=[20,4,-30];
  await queueAttackApproach(t.actor,t.node,t.e,t.p);
  const node=t.actor.objectActionState.list.head.action;
  assert.deepEqual(Array.from({length:4},(_,i)=>actionParameter(node,i)),[20,30,4,0x80000004]);
  const failed=fixture();failed.actor.attackTargetChanged=1;delete failed.p.newTarget;
  await assert.rejects(queueAttackApproach(failed.actor,failed.node,failed.e,failed.p),/newTarget/);
  assert.equal(failed.actor.objectActionState.list.count,0);assert.equal(actionParameter(failed.node,0),failed.target.id);
});
