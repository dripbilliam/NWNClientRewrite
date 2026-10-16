const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native visual effect ${n} is unavailable`);return v|0;};
const vector=(v,n)=>{if(!Array.isArray(v)||v.length!==3||v.some(x=>typeof x!=='number'))throw new Error(`Native visual effect ${n} is unavailable`);return v.map(f);};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native visual effect provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandEffectVisualEffect14051c820. The original groups expanded
// scale/translation/rotation reads at argc>=5. Old authored NCS uses1/2 args.
// Three/four arguments leave extra native VM cells; refuse that unowned path.
export function constructVisualEffect(args,creatorId,p){
  if(args.length===3||args.length===4)throw new Error('Native partial visual-transform VM argument ownership is unavailable');
  if(args.length<1)throw new Error('Native visual effect ID argument is unavailable');
  if(typeof p?.create!=='function')throw new Error('Native visual effect constructor owner is unavailable');
  const effect=p.create(30,creatorId,[integer(args[0],'visual ID'),0,args.length>=2?integer(args[1],'miss flag'):0],8);
  if(!Array.isArray(effect.floats)||!Array.isArray(effect.vectors))throw new Error('Native visual effect transform storage is unavailable');
  effect.floats[0]=args.length>=5?f(args[2]):1;
  effect.vectors[0]=args.length>=5?vector(args[3],'translation'):[0,0,0];effect.vectors[1]=args.length>=5?vector(args[4],'rotation'):[0,0,0];
  return effect;
}

// EffectBeam140517cb0. Active VISUALEFFECTS Type_FD must uppercase to
// exactly B; other rows return the original invalid effect. Transform args
// are read as a group at argc>=7, matching the visual constructor's pattern.
export function constructBeamEffect(args,creatorId,p){
  if(args.length<4||args.length===5||args.length===6)throw new Error('Native beam VM argument grouping is unavailable');
  const id=integer(args[0],'beam visual ID'),kind=call(p,'visualType',id);
  if(!kind.found||String(kind.value).split('\0')[0].replace(/[a-z]/g,c=>c.toUpperCase())!=='B')return call(p,'invalid');
  const effect=call(p,'create',32,creatorId,[id,integer(args[2],'beam body part'),integer(args[3],'beam miss flag')],8);
  effect.objectIds[0]=integer(args[1],'beam source')>>>0;effect.floats[0]=args.length>=7?f(args[4]):1;
  effect.vectors[0]=args.length>=7?vector(args[5],'beam translation'):[0,0,0];effect.vectors[1]=args.length>=7?vector(args[6],'beam rotation'):[0,0,0];return effect;
}
// OnApplyBeam140427a20 retains its record and applies a shared-ID type30
// child for creature/placeable/door. OnRemoveBeam140435fd0 returns1 only;
// removal of the copied visual is owned by the effect-ID removal traversal.
export async function applyBeamEffect(actor,effect,p,loading=0){
  if([5,9,10].includes(actor.objectType)){
    const child=call(p,'copyConstruct',effect,0);child.type=30;
    // The constructor cleared payload. This owner explicitly transfers only
    // source object0, integers0..2, float0 and the two vectors.
    child.objectIds[0]=effect.objectIds[0];for(let i=0;i<3;i++)child.integers[i]=effect.integers[i];child.floats[0]=effect.floats[0];child.vectors=effect.vectors.map(v=>v.slice());
    await call(p,'apply',actor,child,loading);
  }return 0;
}

// OnApplyLight14042ed70..14042ee1f. Its native copy constructor resets
// integer storage before integer0 is written. OnRemoveLight140437810 returns1;
// the copied type30 is removed by the outer ID/property-ID traversal.
export async function applyLightEffect(actor,effect,p,loading=0){
 if(call(p,'asCreature',actor)){
  const child=call(p,'copyConstruct',effect);child.type=30;child.integers[0]=integer(effect.integers?.[0],'light visual ID');
  await call(p,'apply',call(p,'asCreature',actor),child,loading|0,0);
 }
 return 0;
}

// The application builds six constant transform channels. Zero scale leaves
// the native constructor's identity scale intact; translation/rotation do not.
export function visualTransform(effect){
  const scale=effect.floats?.[0];if(typeof scale!=='number')throw new Error('Native visual effect scale storage is unavailable');
  return{scale:scale===0?1:f(scale),translate:vector(effect.vectors?.[0],'translation storage'),rotate:vector(effect.vectors?.[1],'rotation storage')};
}
// OnApplyVisualEffect140434fc0. Values below are internal presentation records,
// not an NWN network packet. Spatial order, exact miss and Type_FD gates match
// the native owner; actual asset/playback delivery is a required recipient.
export async function applyVisualEffect(actor,effect,p){
  if(!actor||!effect)return 1;
  const visualId=integer(effect.integers?.[0],'visual ID'),flag=integer(effect.integers?.[1],'visual flag')&255,miss=integer(effect.integers?.[2],'miss flag');
  const override=integer(effect.objectIds?.[0],'visual source override')>>>0,sourceId=override===0x7f000000?integer(effect.creatorId,'visual creator')>>>0:override;
  const transform=visualTransform(effect);
  if(visualId===119&&(integer(call(p,'plot',actor),'plot flag')!==0||integer(actor.nativeDestroyableF0,'destroyable flag')===0))return 1;
  let targetId=actor.id>>>0,point=[0,0,0],missMode=0;
  if(miss===1){
    targetId=0x7f000000;point=vector(await call(p,'missPoint',actor,effect.creatorId,actor.id),'miss point');
    const position=vector(call(p,'position',actor),'target position');missMode=point[2]===f(position[2]+f(1))?1:2;
  }
  const kind=call(p,'visualType',visualId),oneShot=kind.found&&['F','P'].includes(String(kind.value).split('\0')[0]);
  if((integer(effect.durationType,'duration type')&7)!==0&&miss!==1&&!oneShot){await call(p,'addLoop',actor,visualId&65535,sourceId,flag,transform);return 0;}
  const area=call(p,'area',actor);if(!area)return 1;
  const position=vector(call(p,'position',actor),'target position'),range=actor.nativeProjectileRange268;
  if(typeof range!=='number')throw new Error('Native visual broadcast range is unavailable');
  const radius=f(f(range)+f(2)),squared=f(radius*radius),first=call(p,'firstByX',area,f(position[0]-radius));if(first===null)return 1;
  for(let i=first;;i++){
    const ids=call(p,'areaIds',area);if(i>=ids.length)return 1;
    const viewer=call(p,'object',ids[i]);if(!viewer)continue;
    const v=vector(call(p,'position',viewer),'viewer position'),d=v.map((x,j)=>f(x-position[j]));
    if(!(f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]))<=squared))continue;
    const client=call(p,'client',viewer.id);if(!client)continue;
    await call(p,'send',client,{visualId:visualId&65535,targetId,sourceId,flag,missMode,position:[...point],duration:f(effect.duration),transform:structuredClone(transform)});
  }
}

const equalTransform=(a,b)=>a?.scale===b?.scale&&['translate','rotate'].every(key=>Array.isArray(a?.[key])&&Array.isArray(b?.[key])&&a[key].length===3&&b[key].length===3&&a[key].every((v,i)=>v===b[key][i]));
const looping=o=>{const list=o.nativeLoopingVisuals160;if(!list||!Array.isArray(list.records)||!Number.isInteger(list.capacity)||list.capacity<list.records.length)throw new Error('Native looping visual list storage is unavailable');return list;};
// AddLoopingVisualEffect14048da00 retains duplicates and doubles capacity
// from16. This representation owns the script-generated constant scope0;
// external timed transform-controller import remains a separate owner.
export function addLoopingVisual(actor,id,sourceId,bodyPart,transform){
  const list=looping(actor);if(list.records.length===list.capacity)list.capacity=list.capacity===0?16:Math.imul(list.capacity,2);
  list.records.push({visualId:integer(id,'loop visual ID')&65535,sourceId:integer(sourceId,'loop source')>>>0,bodyPart:integer(bodyPart,'body part')&255,transform:structuredClone(transform)});
}
// RemoveLoopingVisualEffect140498960 scans backwards, removes just the
// LAST match, shifts subsequent records, and retains allocation capacity.
export function removeLoopingVisual(actor,id,sourceId,bodyPart,transform){
  const list=looping(actor);id=integer(id,'loop visual ID')&65535;sourceId=integer(sourceId,'loop source')>>>0;bodyPart=integer(bodyPart,'body part')&255;
  for(let i=list.records.length-1;i>=0;i--){const row=list.records[i];if(row.visualId===id&&row.sourceId===sourceId&&row.bodyPart===bodyPart&&equalTransform(row.transform,transform)){list.records.splice(i,1);return 1;}}
  return 0;
}
// OnRemoveVisualEffect140439730 rebuilds the same constant scope, then
// delegates removal regardless of current Type_FD/instant/miss classification.
export function removeVisualEffect(actor,effect){
  const override=integer(effect.objectIds?.[0],'visual source override')>>>0,source=override===0x7f000000?integer(effect.creatorId,'visual creator')>>>0:override;
  return removeLoopingVisual(actor,integer(effect.integers?.[0],'visual ID'),source,integer(effect.integers?.[1],'body part'),visualTransform(effect));
}
