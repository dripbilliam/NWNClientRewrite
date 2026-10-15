import { OBJECT_INVALID } from './game_object_array.js';
import { addObjectAction, actionParameter } from './object_actions.js';
import { subtractWorldTimes } from './reputation.js';

const f = Math.fround;
const floatBits = value => { const view = new DataView(new ArrayBuffer(4)); view.setFloat32(0, value, true); return view.getInt32(0, true); };
const integer = (value, name) => { if (!Number.isInteger(value)) throw new Error(`Native movement ${name} is unavailable`); return value | 0; };

// AIActionWait1404aaf54..1404ab00d. Signed-64 truncation then low uint32,
// not a clamped duration. The original compares the time remainder only.
export async function executeWait(actor, node, p) {
  if (integer(await p.dead(actor),'dead flag') === 1 || integer(await p.dying(actor),'dying flag') === 1) return 3;
  const milliseconds = f(actionParameter(node,0) * f(1000));
  const signed64 = Number.isFinite(milliseconds) && milliseconds >= -(2 ** 63) && milliseconds < 2 ** 63
    ? BigInt(Math.trunc(milliseconds)) : -(1n << 63n); // x64 indefinite integer.
  const duration = Number(BigInt.asUintN(32,signed64));
  const state = actor.objectActionState;
  const elapsed = subtractWorldTimes(await p.worldTime(),{day:state.startDay,time:state.startTime},p.dayLength);
  if (elapsed.status !== 0) throw new Error('Native wait time subtraction left uninitialized output');
  return elapsed.milliseconds < duration ? 1 : 2;
}

// AddPathfindingWaitActionToFront14037fc80..14037fd8b. Client lookup,
// rather than the PC/familiar flag, selects .1 instead of .3 seconds.
export async function addPathfindingWaitFront(actor,group,p){
  if(typeof p.client!=='function')throw new Error('Native pathfinding wait client provider is unavailable');
  addObjectAction(actor.objectActionState,30,group,[{type:2,value:floatBits(await p.client(actor.id)?f(.1):f(.3))}],true);
  return 1;
}

// AIActionCheckMoveToPointRadius1403b5b00. Action18 uses horizontal
// distance +0.01 tolerance and retains the original group on retry.
export async function checkMovePointRadius(actor,node,p){
  if(await p.dead(actor)===1||await p.dying(actor)===1)return 3;
  const point=[0,1,2].map(i=>actionParameter(node,i)),areaId=actionParameter(node,3),target=actionParameter(node,4),run=actionParameter(node,5),range=actionParameter(node,6);
  if(!await p.moduleArea(areaId))return 3;
  const area=await p.area(actor),dx=f(f(actor.position[0])-f(point[0])),dy=f(f(-actor.position[2])-f(point[1])),tolerance=f(f(range)+f(.01));
  if((!area||area.id===areaId)&&f(f(f(dx*dx)+f(dy*dy))+0)<=f(tolerance*tolerance))return 2;
  addObjectAction(actor.objectActionState,18,node.groupId,Array.from({length:7},(_,i)=>({type:node.parameterTypes[i],value:node.parameterData[i]})),true);
  await addMoveToPointFront(actor,node.groupId,[point[0],point[2],f(-point[1])],areaId,target,run,range,0,0,0,0,0,0,0,p);
  await addPathfindingWaitFront(actor,node.groupId,p);return 2;
}

// AIActionCheckMoveToObjectRadius1403b4580..1403b5107. A failed use check
// can tighten blocked-LOS stop distance and queue wait/move/check in order.
export async function checkMoveRadius(actor,node,p){
  const requireProvider=name=>{if(typeof p[name]!=='function')throw new Error(`Native radius-check provider ${name} is unavailable`);return p[name];};
  if(integer(await p.dead(actor),'dead flag')===1||integer(await p.dying(actor),'dying flag')===1)return 3;
  const id=actionParameter(node,0),run=actionParameter(node,1),losCheck=actionParameter(node,4),transparent=node.parameterCount>5?actionParameter(node,5):0;
  let distance=f(actionParameter(node,2)),maximum=f(actionParameter(node,3));
  const gameObject=await p.object(id),target=gameObject&&await p.asObject(gameObject);if(!target)return 3;
  const out={point:[0,0,0],range:0};await p.useRange(actor,id,out);
  let area=await p.area(target);
  if(!await p.area(target)){
    const creature=await p.asCreature(gameObject);if(!creature)return 3;
    area=await requireProvider('moduleArea')(creature.nativeMovementAreaId);out.point=creature.nativeMovementGoal?.slice();
  }
  if(!area||!await p.area(actor))return 3;
  const actorArea=await p.area(actor);
  if(![distance,maximum,out.range].every(Number.isFinite)||!out.point?.every(Number.isFinite))throw new Error('Native radius-check point/ranges are unavailable');
  if(maximum<f(distance+f(.01)))maximum=f(distance+f(.01));
  const dx=f(f(actor.position[0])-f(out.point[0])),dy=f(f(actor.position[2])-f(out.point[2]));
  if(area===actorArea&&f(f(dy*dy)+f(dx*dx))<=f(maximum*maximum)){
    const result=integer(await p.inUseRange(actor,id,f(f(maximum-out.range)-f(.1)),transparent),'in-use-range result');
    const from=actor.position.map(f),to=target.position.map(f);from[1]=f(from[1]+1);to[1]=f(to[1]+1);
    if(result!==0)return 2;
    if(integer(losCheck,'LOS flag')!==0&&integer(await p.lineOfSight(await p.area(actor),from,to,actor.id,id,1),'LOS result')===0){
      let minimum=0;
      if(gameObject.objectType===5){
        if(!actor.nativePathInfo)throw new Error('Native radius-check path information is unavailable');
        minimum=f(actor.nativePathInfo.field8);const creature=await p.asCreature(gameObject);
        if(creature)minimum=f(minimum+creature.nativePathInfo.field8);
      }
      if(!Number.isFinite(minimum))throw new Error('Native radius-check minimum range is unavailable');
      if(distance<=minimum)return 3;
      distance=f(f(distance*f(.8))-f(.1));if(distance<=minimum)distance=minimum;
    }
  }
  requireProvider('setLock');requireProvider('client');
  addObjectAction(actor.objectActionState,17,node.groupId,[{type:3,value:id},{type:1,value:run},
    {type:2,value:floatBits(distance)},{type:2,value:floatBits(maximum)},{type:1,value:losCheck},{type:1,value:transparent}],true);
  await addMoveToPointFront(actor,node.groupId,out.point,area.id,id,run,distance,0,0,0,0,0,0,1,p);
  await addPathfindingWaitFront(actor,node.groupId,p);return 2;
}

// AIActionCheckInterAreaPathfinding1403b1dc0. Owned route arrays are shifted
// independently (the native owner copies a8 into BOTH allocations).
export async function checkInterArea(actor,node,p){
  if(integer(await p.dead(actor),'dead flag')===1||integer(await p.dying(actor),'dying flag')===1)return 3;
  if(!await p.area(actor))return 1;
  const path=actor.nativePathInfo;if(!path)throw new Error('Native interarea-check path information is unavailable');
  const count=path.raw.getInt32(0xa4,true);
  if(count<2)path.resetInterArea();
  else{
    for(const name of ['setIntraAreaGoal','setLock','client'])if(typeof p[name]!=='function')throw new Error(`Native interarea-check provider ${name} is unavailable`);
    const ids=path.allocations.get(0xa8);if(!(ids instanceof Uint32Array)||ids.length<count)throw new Error('Native interarea-check route allocation is unavailable');
    path.allocations.set(0xa8,ids.slice(1,count));
    if(count>2)path.allocations.set(0xb0,ids.slice(1,count-1));else path.allocations.delete(0xb0);
    path.raw.setInt32(0xa4,count-1,true);
    if(await p.area(actor)){
      await p.setIntraAreaGoal(path);
      const point=[path.raw.getFloat32(0x4c,true),path.raw.getFloat32(0x54,true),-path.raw.getFloat32(0x50,true)],areaId=path.raw.getUint32(0x60,true);
      path.raw.setFloat32(0x4c,f(point[0]-5),true);path.raw.setInt32(0xa0,1,true);
      await addMoveToPointFront(actor,node.groupId,point,areaId,OBJECT_INVALID,0,0,0,0,0,0,0,0,0,p);
      await addPathfindingWaitFront(actor,node.groupId,p);
    }
  }
  addObjectAction(actor.objectActionState,30,node.groupId,[{type:2,value:floatBits(.75)}],true);return 2;
}

// AddMoveToPointActionToFront14037fae0..14037fc73. Preserve all native
// argument slots/bit packing; later movement owners interpret these flags.
// point uses renderer[X,Z,-Y], while action float slots store native[X,Y,Z].
export async function addMoveToPointFront(actor, group, point, areaId, targetId, arg6, distance, arg8, arg9, arg10, arg11, arg12, arg13, arg14, p) {
  return addMoveToPoint(actor,group,point,areaId,targetId,arg6,distance,arg8,arg9,arg10,arg11,arg12,arg13,arg14,p,true);
}
// AddMoveToPointAction14037f940 appends; parameter encoding and orientation
// lock clearing are identical to the front-inserting variant.
export async function addMoveToPointBack(actor,group,point,areaId,targetId,arg6,distance,arg8,arg9,arg10,arg11,arg12,arg13,arg14,p){
  return addMoveToPoint(actor,group,point,areaId,targetId,arg6,distance,arg8,arg9,arg10,arg11,arg12,arg13,arg14,p,false);
}
async function addMoveToPoint(actor, group, point, areaId, targetId, arg6, distance, arg8, arg9, arg10, arg11, arg12, arg13, arg14, p,front) {
  if (!Array.isArray(point) || point.length !== 3 || !point.every(Number.isFinite) || ![distance,arg8].every(Number.isFinite))
    throw new Error('Native movement point/distance is unavailable');
  [group,areaId,targetId,arg6,arg9,arg10,arg11,arg12,arg13,arg14].forEach(v=>integer(v,'argument'));
  if (typeof p.setLock !== 'function') throw new Error('Native movement orientation lock provider is unavailable');
  let flags = ((arg9 * 2) | arg6) >>> 0;
  if (f(arg8) !== 0) flags |= 4;
  flags |= (((arg11 & 7) * 2 | arg13) << 3);
  if (arg12 !== 0) flags |= (arg12 & 3) << 7;
  flags |= (arg14 & 1) << 9;
  const params = [
    {type:2,value:floatBits(point[0])},{type:2,value:floatBits(-point[2])},{type:2,value:floatBits(point[1])},
    {type:3,value:areaId},{type:3,value:targetId},{type:1,value:flags},
    {type:2,value:floatBits(distance)},{type:1,value:arg10},{type:2,value:floatBits(arg8)},
  ];
  addObjectAction(actor.objectActionState,1,group,params,front);
  await p.setLock(actor,OBJECT_INVALID);
  return 1;
}

// Approach branch of AIActionAttackObject1403dd99f..1403dded1.
// Result2 replaces the executing attack with move1/face19/check17/attack12.
// No preview movement or guessed path result is applied by this owner.
export async function queueAttackApproach(actor, node, eligibility, p) {
  const required = name => { if (typeof p[name] !== 'function') throw new Error(`Native attack approach provider ${name} is unavailable`); return p[name]; };
  const targetId = eligibility.targetId >>> 0, target = await required('object')(targetId);
  if (!target) throw new Error('Native attack approach target disappeared');
  const change = async target => { await required('changeTarget')(actor,node,target?.id??OBJECT_INVALID); return target ? 1 : 3; };
  if (integer(actor.attackTargetChanged,'attack-target changed flag') !== 0) {
    const replacement = await required('newTarget')(actor,targetId);
    if (replacement) actor.attackTargetChanged = 1;
    return change(replacement);
  }
  let areaId, point = eligibility.targetPosition;
  if (eligibility.targetArea) areaId = eligibility.targetArea.id;
  else {
    if (target.objectType !== 5 || actor.nativeField948 !== OBJECT_INVALID)
      return change(await required('newTarget')(actor,targetId));
    areaId = target.nativeMovementAreaId; point = target.nativeMovementGoal;
  }
  const previous = actor.attackTargetPosition;
  if (![previous,actor.position,point].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))
    throw new Error('Native attack approach stored position is unavailable');
  const unchanged = !previous.every(v=>f(v)===0) && previous.every((v,i)=>f(v)===f(actor.position[i]));
  if (unchanged) {
    if (actor.isPC || actor.isPossessedFamiliar) await required('feedback')(actor,218);
    if (await required('ranged')(actor) === 0) {
      const replacement = await required('newTarget')(actor,targetId);
      if (replacement) { actor.attackTargetChanged = 1; return change(replacement); }
    }
    if (actor.isPC || actor.isPossessedFamiliar) return change(null);
  } else actor.attackTargetPosition = actor.position.map(f);
  integer(areaId,'approach area ID');
  if (!actor.nativePathInfo) throw new Error('Native attack approach path information is unavailable');
  let distance = f(eligibility.desired), maximum = f(eligibility.maximum);
  if (!eligibility.outsideMaximumRange && eligibility.spatialResult === 0) {
    if (target.objectType === 5) {
      if (!target.nativePathInfo) throw new Error('Native attack approach target path information is unavailable');
      distance = f(actor.nativePathInfo.field8 + target.nativePathInfo.field8);
    } else distance = actor.nativePathInfo.field4;
  }
  if (![distance,maximum].every(Number.isFinite)) throw new Error('Native attack approach ranges are unavailable');
  required('setLock');
  if (eligibility.spatialResult === 0) actor.nativePathInfo.field19c = 1;
  const group = node.groupId;
  addObjectAction(actor.objectActionState,12,group,[{type:3,value:targetId}],true);
  addObjectAction(actor.objectActionState,17,group,[{type:3,value:targetId},{type:1,value:1},
    {type:2,value:floatBits(distance)},{type:2,value:floatBits(maximum)},{type:1,value:1}],true);
  addObjectAction(actor.objectActionState,19,group,[{type:3,value:targetId}],true);
  await addMoveToPointFront(actor,group,point,areaId,target.objectType===10?OBJECT_INVALID:targetId,1,distance,0,0,0,0,0,0,0,p);
  return 2;
}
