import {secondsToWorldDelta,addWorldTimes} from './world_timer.js';
const f=Math.fround;
const view=(bytes,size)=>{
 if(!(bytes instanceof Uint8Array)||bytes.byteLength!==size)throw new Error(`Native visual ${size}-byte storage is unavailable`);
 return new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
};
import {restartVisualCurve} from './visual_curve.js';
export {restartVisualCurve} from './visual_curve.js';

// Complete field loader1402e9ef0..1402ea10d. The output is caller-owned,
// not a newly zeroed struct: inactive clock slots20/30 are left untouched.
// Scalar FLOAT takes precedence over the same-named nested curve structure.
export async function loadVisualCurve(bytes,data,name,fallback,p){
 const v=view(bytes,64),direct=await p.read(data,'float',name,f(fallback));
 let to=f(direct.value),from=f(fallback),timer=0,lerp=0,duration=0,progress=0;
 if((direct.status|0)!==0)from=to;
 else{
  const root=await p.struct(data,name);
  if((root.status|0)!==0){
   timer=(await p.read(root.value,'int','TimerType',0)).value|0;
   to=f((await p.read(root.value,'float','ValueTo',to)).value);
   lerp=(await p.read(root.value,'int','LerpType',0)).value|0;
   if(lerp!==0){
    from=f((await p.read(root.value,'float','ValueFrom',from)).value);
    duration=f((await p.read(root.value,'float','LerpDuration',0)).value);
    progress=f((await p.read(root.value,'float','LerpProgress',0)).value);
    // These reads really occur, but the original discards both results.
    await p.read(root.value,'int','BehaviorFlags',0);await p.read(root.value,'int','RepeatsRemaining',0);
   }
  }
 }
 v.setInt32(0,timer,true);v.setFloat32(4,to,true);v.setFloat32(8,from,true);v.setInt32(12,lerp,true);
 v.setFloat32(16,duration,true);v.setFloat32(20,progress,true);
 for(const offset of[24,40,56])v.setBigUint64(offset,0n,true);
 await restartVisualCurve(bytes,p);return bytes;
}

// Complete LoadVisualTransform14048f8c0..14048fe10. A single64-byte scratch
// value is reused in native field order. Copying each curve into its object
// member restarts it a second time, which is observable in both clock domains.
export async function loadVisualTransform(bytes,data,p,scratch=new Uint8Array(64)){
 view(bytes,640);view(scratch,64);
 for(const[name,offset,fallback]of[
  ['AnimationSpeed',0x240,1],['ScaleX',0,1],['ScaleY',0x40,1],['ScaleZ',0x80,1],
  ['RotateX',0xc0,0],['RotateY',0x100,0],['RotateZ',0x140,0],
  ['TranslateX',0x180,0],['TranslateY',0x1c0,0],['TranslateZ',0x200,0],
 ]){
  await loadVisualCurve(scratch,data,name,fallback,p);bytes.set(scratch,offset);
  await restartVisualCurve(bytes.subarray(offset,offset+64),p);
 }
 return bytes;
}

// Session-local monotonic epoch and the existing full WorldTimer owners.
// No clock snapshot is introduced by loading: GetWorldTime reads its stored
// counter/offsets, including pause and fixed-tick state.
export function visualTransformClockProviders(worldTimer,clock){return{
 clock:()=>{if(typeof clock!=='function')throw new Error('Native visual monotonic clock is unavailable');return clock();},
 worldTimer:()=>worldTimer??null,
 worldSeconds:(timer,seconds)=>secondsToWorldDelta(seconds,timer.secondsPerDay).time,
 worldTime:timer=>timer.time(),
 addWorld:(timer,now,delta)=>addWorldTimes(now,delta,timer.dayLength),
};}

const ordered=map=>[...map].sort((a,b)=>a[0]-b[0]);
// IsZeroMap140496290 and its vector/single-curve helpers4961c0/496170.
// The default predicate is literally all-zero defined fields, not identity
// scale/speed1. Timer caches are ignored, as are the scope keys.
export function zeroVisualTransforms(map){
 for(const bytes of map.values()){
  const v=view(bytes,640);
  for(let base=0;base<640;base+=64){
   for(const offset of[0,12,24,28])if(v.getInt32(base+offset,true)!==0)return false;
   for(const offset of[4,8,16,20])if(v.getFloat32(base+offset,true)!==0)return false;
  }
 }
 return true;
}
// Native tree equality14048aef0 compares keys and only each curve's ValueTo.
// Changes to interpolation, endpoints-from, clocks/flags alone are ignored.
export function equalVisualTransforms(a,b){
 if(a.size!==b.size)return false;
 const left=ordered(a),right=ordered(b);
 for(let i=0;i<left.length;i++){
  if(left[i][0]!==right[i][0])return false;
  const x=view(left[i][1],640),y=view(right[i][1],640);
  for(let base=0;base<640;base+=64)if(x.getFloat32(base+4,true)!==y.getFloat32(base+4,true))return false;
 }
 return true;
}

// Complete SetVisualTransform14049c020..14049c163. Standard-map construction/
// clear/copy and item/equipment lookup are lower providers. Object identity
// and canonical game IDs are unaffected by this separately owned state.
export async function assignVisualTransforms(object,incoming,p){
 let current=object.nativeVisualTransforms2b0??null;
 if(current===null?zeroVisualTransforms(incoming):current.size===incoming.size&&equalVisualTransforms(current,incoming))return;
 if(current===null){current=await p.constructMap('owned');object.nativeVisualTransforms2b0=current;}
 if(current!==incoming){await p.clearMap(current);await p.copyMap(current,incoming);}
 if(await p.asItem(object)===null)return;
 const item=await p.asItem(object),id=item.possessorId>>>0;if(id===0x7f000000)return;
 const creature=await p.creature(id);if(creature===null)return;
 const slot=(await p.equipmentSlot(creature,item))|0;
 if(slot===16||slot===32)await p.copyHand(creature,slot===16?0xab0:0xac0,incoming);
}

// Complete LoadVisualTransform140497bb0..140497dec. A present empty list
// takes precedence over the legacy structure. Duplicate INT scopes load into
// the same value; failed elements report the native assertion and discard the
// entire temporary map, retaining previously assigned object transforms.
export async function loadObjectVisualTransforms(object,data,p){
 const list=await p.list(data,'VisTransformList');let map;
 if((list.status|0)!==0){
  const count=(await p.count(list.value))>>>0;map=await p.constructMap('temporary');
  try{
   for(let i=0;i<count;i++){
    const row=await p.element(list.value,i);
    if((row.status|0)===0){await p.assertFailure('LoadVisualTransform',0x60e,'pRes->GetListElement(&subStruct, &list, i)');return;}
    const scope=(await p.read(row.value,'int','Scope',0)).value|0;
    if(!map.has(scope))map.set(scope,new Uint8Array(640));
    await p.loadTransform(map.get(scope),row.value);
   }
   const entries=ordered(map);map.clear();for(const entry of entries)map.set(...entry);
   await p.assignTransforms(object,map);
  }finally{await p.releaseMap(map);}
 }else{
  const root=await p.struct(data,'VisualTransform');if((root.status|0)===0)return;
  map=await p.constructMap('temporary');
  try{const value=new Uint8Array(640);map.set(0,value);await p.loadTransform(value,root.value);await p.assignTransforms(object,map);}
  finally{await p.releaseMap(map);}
 }
}
