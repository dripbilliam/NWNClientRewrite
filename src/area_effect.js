import {OBJECT_INVALID} from './game_object_array.js';
import {nativeFloatEntry} from './movement_rate.js';
import {spellStringEntry} from './spell_metadata.js';
import {NativeIdList} from './native_id_list.js';
import {normalizeOrientation} from './combat_lifecycle.js';
import {intersectAreaSegments} from './area_collision.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native area effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native area effect provider ${n} is unavailable`);return p[n](...args);};
const vector=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native area-effect vector is unavailable');return v.map(f);};
const ids=v=>{if(!(v instanceof NativeIdList))throw new Error('Native area-effect ID list is unavailable');return v;};
// ExecuteCommandEffectAreaEffect140517830 accepts any raw INT ID. Position
// FLOAT0..2 start zero; script names are full values, not guessed defaults.
export function constructAreaEffect(args,creator,p){
  const [id,enter='',heartbeat='',exit='']=args;
  if(![enter,heartbeat,exit].every(v=>typeof v==='string'))throw new Error('Native area-effect script strings are unavailable');
  const e=call(p,'create',31,creator,[integer(id,'ID')],8);e.floats[0]=e.floats[1]=e.floats[2]=0;e.strings??=Array(6).fill('');e.strings.splice(0,3,enter,heartbeat,exit);return e;
}
// Derived constructor4f59d0, after base object construction/registration.
// Width/length are intentionally absent until the rectangle setter writes them.
export function initializeAreaEffect(o,now){
  o.nativeAreaEffectCreator330=OBJECT_INVALID;o.nativeAnchor334=OBJECT_INVALID;o.nativeEntering338=OBJECT_INVALID;o.nativeExiting33c=OBJECT_INVALID;
  o.nativeShape310=0;o.nativeRadius318=f(0);o.nativeVertices328=null;o.nativeAreaEffectSpellId=-1;
  o.nativeHeartbeat388={day:0,time:0};o.nativeDuration390=0;o.nativeDurationType394=2;
  o.nativeSpellSaveDC340=14;o.nativeCasterLevel344=0;o.nativePreviousTime={...now};
  o.scripts={heartbeat:'',userDefined:'',enter:'',exit:''};
}
// CNWSAreaOfEffectObject::SetCreator4f91f0. Current spell218 and effect
// spell314 are separate fields. Override metadata paths deliberately retain
// constructor defaults except that equipment overrides zero the meta BYTE.
export function setAreaEffectCreator(o,creator,level,spell,cls,meta,dc,feat,spontaneous,p){
  o.nativeAreaEffectCreator330=integer(creator,'creator')>>>0;o.nativeCasterLevel344=integer(level,'caster level');
  o.nativeSpellId218=integer(spell,'spell');o.nativeAreaEffectSpellId=o.nativeSpellId218;o.nativeSpellSaveDC340=14;
  const source=call(p,'creature',o.nativeAreaEffectCreator330);if(!source||o.nativeSpellId218===-1)return;
  if(integer(source.nativeCasterOverride820,'caster override')===0){
    if(integer(source.nativeEquipmentLock97c,'equipment override')!==0&&[source.nativeSpellOverride9e8,source.nativeSpellOverride9ec,source.nativeSpellOverride9f0].some(id=>integer(id,'override spell')===o.nativeSpellId218)){
      o.nativeSpellClass22c=255;o.nativeSpellMetamagic22d=0;
    }else{
      o.nativeSpellClass22c=integer(cls,'class')&255;o.nativeSpellMetamagic22d=integer(meta,'metamagic')&255;
      o.nativeSpellFeat23c=integer(feat,'feat')&65535;o.nativeSpellSpontaneous228=integer(spontaneous,'spontaneous');
    }
  }
  o.nativeSpellSaveDC340=integer(dc,'DC');
}
// SetShape4f9310: circular radius is raw FLOAT; rectangle caches its half
// diagonal using FLOAT operations, allocates four zero vectors and untethers.
export function setAreaEffectShape(o,shape,width,length=0){
  shape=integer(shape,'shape')&255;o.nativeShape310=shape;
  if(shape===0)o.nativeRadius318=f(width);
  else if(shape===1){o.nativeWidth31c=f(width);o.nativeLength320=f(length);
    const w=f(f(width)*f(.5)),l=f(f(length)*f(.5));o.nativeRadius318=f(Math.sqrt(f(f(l*l)+f(w*w))));
    o.nativeVertices328=Array.from({length:4},()=>[0,0,0]);o.nativeAnchor334=OBJECT_INVALID;
  }
}
// LoadAreaEffect4f7e70. Active VFX_PERSISTENT physical rows supply shape,
// script defaults and a lowercased tag; nonempty per-effect overrides come later.
export function loadAreaEffect(o,id,table,p){
  o.nativeAreaEffectId30c=integer(id,'ID');const string=name=>spellStringEntry(table,o.nativeAreaEffectId30c,name),shape=string('SHAPE').split('\0')[0];
  if(shape==='C')setAreaEffectShape(o,0,nativeFloatEntry(table,o.nativeAreaEffectId30c,'RADIUS').value);
  else if(shape==='R')setAreaEffectShape(o,1,nativeFloatEntry(table,o.nativeAreaEffectId30c,'WIDTH').value,nativeFloatEntry(table,o.nativeAreaEffectId30c,'LENGTH').value);
  else call(p,'warning',"Unknown SHAPE in VFX_PERSISTENT.2da. Use 'C' for Circle, 'R' for Rectangle");
  o.scripts.enter=string('ONENTER');o.scripts.heartbeat=string('HEARTBEAT');o.scripts.exit=string('ONEXIT');
  const label=string('LABEL');if(/[^\x00-\x7f]/.test(label))throw new Error('Native non-ASCII area-effect tag folding is unavailable');
  o.tag=label.replace(/[A-Z]/g,c=>c.toLowerCase());call(p,'addTag',o,o.tag);
}
// Non-instrumentation AIUpdate4f5de0. Timing providers expose both native
// world-time components; elapsed milliseconds are the returned remainder.
export async function updateAreaEffect(o,p){
  const ticks=call(p,'microseconds'),now=call(p,'worldTime'),delta=call(p,'difference',now,o.nativePreviousTime),heartbeat=call(p,'difference',now,o.nativeHeartbeat388);
  if(delta.status!==0||heartbeat.status!==0)throw new Error('Native area-effect future-time scratch branch is unavailable');
  o.nativePreviousTime={...now};o.nativeFrameElapsedD4=integer(delta.milliseconds,'elapsed time')>>>0;
  if((integer(heartbeat.milliseconds,'heartbeat time')>>>0)>=6000){
    if((o.nativeHeartbeat388.time>>>0)!==0)await call(p,'runScript',o,0,0);o.nativeHeartbeat388={...now};
  }
  if((integer(o.nativeAnchor334,'anchor')>>>0)!==OBJECT_INVALID&&(integer(o.nativeShape310,'shape')&255)===0){
    const anchor=call(p,'object',o.nativeAnchor334);
    if(anchor){const point=[...call(p,'position',anchor)];if(call(p,'area',o))await call(p,'updateSubareas',o,point);await call(p,'setPosition',o,point,0);}
    else await call(p,'enqueue',11,o.id,o.id,0,null);
  }
  if((integer(o.nativeDurationType394,'duration type')&255)===1){
    const remaining=integer(o.nativeDuration390,'remaining time')>>>0;
    if(remaining<=o.nativeFrameElapsedD4){await call(p,'enqueue',11,o.id,o.id,0,null);return;}
    o.nativeDuration390=(remaining-o.nativeFrameElapsedD4)>>>0;
  }
  await call(p,'updateEffects',o,now,ticks);
}
// GetPosition4f7830 follows an existing creature only for circular effects.
// InAreaOfEffect4f78f0 itself deliberately uses the stored center instead.
export function areaEffectPosition(o,p){
  if((o.nativeAnchor334>>>0)!==OBJECT_INVALID&&(o.nativeShape310&255)===0){const target=call(p,'object',o.nativeAnchor334);if(target){
    if(target.objectType!==5)throw new Error('Native circular area-effect anchor is not a creature');return vector(call(p,'position',target));}}
  return vector(call(p,'position',o));
}
export function inAreaEffect(o,point,position){
  point=vector(point);position=vector(position);const d=point.map((n,i)=>f(n-position[i])),radius=f(o.nativeRadius318),
    distance=f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2]));
  if(!(f(radius*radius)>=distance))return 0;
  if((integer(o.nativeShape310,'shape')&255)===0)return 1;
  if(!Array.isArray(o.nativeVertices328)||o.nativeVertices328.length!==4)throw new Error('Native area-effect rectangle vertices are unavailable');
  for(let i=0;i<4;i++){const a=vector(o.nativeVertices328[i]),b=vector(o.nativeVertices328[(i+1)%4]),edge=b.map((n,j)=>f(n-a[j])),offset=point.map((n,j)=>f(n-a[j]));
    if(f(f(edge[0]*offset[1])-f(edge[1]*offset[0]))>0)return 0;}
  return 1;
}
// ClosestPointOnLineSegment231aa0. Numerator/denominator add Y then X
// then Z; every intermediate is FLOAT. Degenerate segments return their start.
export function closestAreaSegmentPoint(start,end,point){
  start=vector(start);end=vector(end);point=vector(point);if(start.every((n,i)=>n===end[i]))return start;
  const d=end.map((n,i)=>f(n-start[i])),offset=point.map((n,i)=>f(n-start[i])),length=f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2]));
  const fraction=length===0?0:f(f(f(f(offset[1]*d[1])+f(offset[0]*d[0]))+f(offset[2]*d[2]))/length),t=Math.max(0,Math.min(1,fraction));
  return d.map((n,i)=>f(f(n*t)+start[i]));
}
export function setAreaEffectAnchor(o,id,p){
  id=integer(id,'anchor')>>>0;const old=o.nativeAnchor334>>>0;
  if(old!==OBJECT_INVALID){const target=call(p,'object',old);if(target){if(target.objectType!==5)throw new Error('Native old area-effect anchor is not a creature');ids(target.nativeFollowingAOEs).remove(o.id);}}
  o.nativeAnchor334=id;const target=call(p,'object',id);if(target){if(target.objectType!==5)throw new Error('Native new area-effect anchor is not a creature');ids(target.nativeFollowingAOEs).append(o.id);}
}
// UpdateSubAreas4f94c0 mutates each CREATURE's membership518 and queues
// script events; it does not execute those scripts inside the spatial scan.
export async function updateAreaEffectSubareas(o,next,p){
  const area=call(p,'area',o);if(!area)return;
  const center=areaEffectPosition(o,p),previous=vector(call(p,'position',o)),radius=f(o.nativeRadius318);
  let low=center[0],high=center[0];if(next){next=vector(next);const x=areaEffectPosition(o,p)[0];low=x>next[0]?next[0]:x;high=next[0]>x?next[0]:x;}
  const first=call(p,'firstByX',area,f(f(low-radius)-f(.5)));if(first===null)return;
  for(let index=first;;index++){
    const spatial=call(p,'areaIds',area);if(index>=spatial.length)return;const actor=call(p,'object',spatial[index]);if(!actor||actor.objectType<5||actor.objectType>14)continue;
    const point=vector(call(p,'position',actor));if(actor.objectType===5){
      const membership=ids(actor.nativeSubareaMembership),inside=membership.indexOf(o.id)>=0;let hit;
      if((o.nativeShape310&255)===0){
        // Native moving-circle sweep uses point+old-center as its projection
        // input. Preserve that operation even though it is an unusual choice.
        const closest=next?closestAreaSegmentPoint(previous,next,point.map((n,i)=>f(n+previous[i]))):previous,
          delta=point.map((n,i)=>f(n-closest[i])),distance=f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]));
        hit=f(radius*radius)>=distance;
        if(hit&&next&&!inside){const d=point.map((n,i)=>f(n-next[i])),endDistance=f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]));
          if(!(endDistance<=f(radius*radius))){membership.append(o.id);await call(p,'event',actor,o,12);membership.remove(o.id);await call(p,'event',actor,o,13);hit=null;}}
      }else hit=call(p,'contains',o,point)===1;
      if(hit===true&&!inside){membership.append(o.id);await call(p,'event',actor,o,12);}
      else if(hit===false&&inside){membership.remove(o.id);await call(p,'event',actor,o,13);}
    }
    if(f(point[0]-high)>radius)return;
  }
}
// EventHandler4f77ac..4f7818 updates last-enter/exit only at dispatch.
export async function dispatchAreaEffectEvent(o,event,p){
  if(event.eventId===11){if(integer(o.nativeDestroyableF0,'destroyable')!==0){await call(p,'removeFromArea',o);await call(p,'destroy',o);}return;}
  if(event.eventId!==10)throw new Error(`Native area-effect event ${event.eventId} is unavailable`);
  const payload=event.payload,code=integer(payload.type??payload.scriptEvent,'script event')&65535;
  if(code===12||code===13){const id=integer(payload.objectIds?.[0]??OBJECT_INVALID,'entering/exiting')>>>0;
    o[code===12?'nativeEntering338':'nativeExiting33c']=id;o.eventObjects??={};o.eventObjects[code===12?'entering':'exiting']=id;
    await call(p,'runScript',o,code===12?2:3,0);}
}
export function areaEffectCreator(o){return o?.objectType===11?integer(o.nativeAreaEffectCreator330,'creator')>>>0:OBJECT_INVALID;}
// SetDuration4f92d0 only overwrites remaining milliseconds for positive
// durations, independently of the BYTE type. CVTTSS2SI is a signed64 conversion.
export function setAreaEffectDuration(o,type,seconds){
  o.nativeDurationType394=integer(type,'duration type')&255;seconds=f(seconds);
  if(seconds>0){const n=f(seconds*f(1000));o.nativeDuration390=Number.isFinite(n)&&n<2**63?Number(BigInt.asUintN(32,BigInt(Math.trunc(n)))):0;}
}
// AddToArea4f6720. Rectangle corners use the normalized orientation, then
// multiply every component by .5 and translate. The Z terms intentionally
// use the same facing Z for both axes, as in the original implementation.
export async function addAreaEffectToArea(o,area,position,flag,p){
  if(!area)return;await call(p,'setArea',o,area);position=vector(position);await call(p,'writePosition',o,position);
  if((o.nativeShape310&255)===1&&o.nativeVertices328){
    const raw=vector(call(p,'orientation',o)),adapted=normalizeOrientation([raw[0],raw[2],f(-raw[1])]),[x,y,z]=[adapted[0],f(-adapted[2]),adapted[1]],w=f(o.nativeWidth31c),l=f(o.nativeLength320),
      lx=f(l*x),ly=f(l*y),lz=f(l*z),wx=f(w*x),nyw=f(f(-y)*w),wz=f(w*z);
    const corners=[[f(nyw+lx),f(ly+wx),f(lz+wz)],[f(lx-nyw),f(ly-wx),f(lz-wz)],
      [f(f(-lx)-nyw),f(f(-ly)-wx),f(f(-lz)-wz)],[f(nyw-lx),f(wx-ly),f(wz-lz)]];
    o.nativeVertices328=corners.map(v=>v.map((n,i)=>f(f(n*f(.5))+position[i])));
  }
  await call(p,'addObject',area,o,flag);ids(area.nativeSubareas).append(o.id);await call(p,'setFieldD8',o,1);await call(p,'updateSubareas',o,null);
}
// RemoveFromSubAreas4f8c40 and RemoveFromArea4f8bb0. During destruction,
// exit scripts run synchronously before the spatial/subarea lists are changed.
export async function removeAreaEffectSubareas(o,synchronous,p){
  const area=call(p,'area',o);if(!area)throw new Error('Native area-effect removal area is unavailable');
  for(let index=0;;index++){const spatial=call(p,'areaIds',area);if(index>=spatial.length)return;const actor=call(p,'object',spatial[index]);if(actor?.objectType!==5)continue;
    if(call(p,'contains',o,vector(call(p,'position',actor)))===0)continue;const membership=ids(actor.nativeSubareaMembership);if(membership.indexOf(o.id)<0)continue;
    membership.remove(o.id);await call(p,synchronous!==0?'dispatchExit':'event',actor,o,13);
  }
}
export async function removeAreaEffectFromArea(o,p){
  const area=call(p,'area',o);if(area){await removeAreaEffectSubareas(o,1,p);await call(p,'removeObject',area,o);ids(area.nativeSubareas).remove(o.id);}
  await call(p,'setArea',o,null);await call(p,'writePosition',o,[0,0,0]);await call(p,'setFieldD8',o,0);
}

// CNWSAreaOfEffectObject::JumpToPoint1404f7a70. The anchor is resolved
// canonically and only the same-area path moves. Cross-area ownership is the
// separate creature AddToArea/RemoveFromArea lifecycle.
export async function jumpAreaEffect(o,area,point,p){
  const actor=call(p,'creature',o.nativeAnchor334);if(!actor||call(p,'area',o)!==area)return;
  const membership=ids(actor.nativeSubareaMembership);
  if(membership.indexOf(o.id)<0)await call(p,'warning','InSubAreasArray does not contain specified area');
  else membership.remove(o.id);
  await call(p,'removeSubareas',o,0);await call(p,'setPosition',o,point,0);
  if(membership.indexOf(o.id)<0)membership.append(o.id);
  await call(p,'updateSubareas',o,null);
}
// GetFirst/NextInPersistentObject525fc0 AoE branch. Cursor308 is an AREA
// spatial index stored as WORD on the effect, not a private filtered snapshot.
export function objectInAreaEffect(first,o,filter,zone,p){
  if(!o)return OBJECT_INVALID;
  if(o.objectType!==11){if([7,13].includes(o.objectType))throw new Error('Native trigger/encounter persistent-object enumeration is unavailable');return OBJECT_INVALID;}
  if(integer(zone,'persistent zone')!==0)return OBJECT_INVALID;const area=call(p,'area',o);if(!area)return OBJECT_INVALID;
  filter=integer(filter,'object filter');const radius=f(o.nativeRadius318),low=f(areaEffectPosition(o,p)[0]-radius),high=f(radius+areaEffectPosition(o,p)[0]);let index;
  if(first){o.nativePersistentCursor308=0;index=call(p,'firstByX',area,low);if(index===null)return OBJECT_INVALID;}
  else index=integer(o.nativePersistentCursor308,'enumeration cursor')&65535;
  const masks={5:1,6:2,7:4,10:8,11:16,12:32,9:64,14:128,13:256};
  for(;;index++){const spatial=call(p,'areaIds',area);if(index>=spatial.length)return OBJECT_INVALID;const candidate=call(p,'object',spatial[index]);if(!candidate)continue;
    let accepts=Boolean(filter&(masks[candidate.objectType]??0));if(candidate.objectType===5&&accepts&&call(p,'dm',candidate)!==0)accepts=false;
    if(!accepts&&(filter&0x7fff)!==0x7fff)continue;const point=vector(call(p,'position',candidate));if(point[0]>high)return OBJECT_INVALID;
    if(call(p,'contains',o,point)===0||call(p,'dead',candidate)!==0)continue;o.nativePersistentCursor308=(index+1)&65535;return candidate.id>>>0;
  }
}
// IntersectingLineSegment4f7b90 tests horizontal boundary crossings. A
// segment entirely inside a circle can return0; its endpoint membership is
// handled separately by InAreaOfEffect. The quadratic's native signs and
// asymmetric root comparisons are preserved instead of using a new formula.
export function intersectAreaEffect(o,start,end,position,hasArea){
  start=vector(start);end=vector(end);position=vector(position);
  if((o.nativeShape310&255)!==0){if(!hasArea)return 0;
    if(!Array.isArray(o.nativeVertices328)||o.nativeVertices328.length!==4)throw new Error('Native area-effect rectangle vertices are unavailable');
    for(let i=0;i<4;i++)if(intersectAreaSegments(start,end,o.nativeVertices328[i],o.nativeVertices328[(i+1)%4]))return 1;return 0;
  }
  const r=f(o.nativeRadius318),low=Math.min(start[0],end[0]),high=Math.max(start[0],end[0]);
  if(end[0]===start[0]){const dx=f(position[0]-end[0]);if(f(-r)>dx||dx>r)return 0;
    const root=f(Math.sqrt(f(f(r*r)-f(dx*dx)))),bottom=f(position[1]-root),top=f(position[1]+root),ymin=Math.min(start[1],end[1]),ymax=Math.max(start[1],end[1]);
    if(ymin>=bottom&&bottom>=ymax)return 1;return Number(ymin>=top&&top>=ymax);
  }
  const slope=f(f(end[1]-start[1])/f(end[0]-start[0])),b=f(f(end[1]-f(end[0]*slope))-position[1]),
    a=f(f(slope*slope)+f(1)),linear=f(f(f(b*slope)-position[0])+f(f(b*slope)-position[0])),constant=f(f(f(position[0]*position[0])-f(b*b))-f(r*r)),
    discriminant=f(f(linear*linear)-f(constant*f(a*f(4))));
  if(0>discriminant)return 0;const root=f(Math.sqrt(discriminant)),denominator=f(a+a),first=f(f(f(-linear)-root)/denominator),second=f(f(root-linear)/denominator);
  if(low>=first&&first>=high)return 1;return Number(low>=second&&second>=high);
}
// Generic area and attached-creature effect creation:35bdf0 /427410.
// Installed scripts choose the VFX_PERSISTENT row and optional callbacks.
export async function createPersistentAreaEffect(target,effect,position,orientation,p,{attached=false,loading=0}={}){
  if(attached){if(target?.objectType!==5)return 1;
    if(loading!==0&&call(p,'dead',target)!==0&&![3,4].includes(effect.durationType&7))return 1;
    if(call(p,'aoe',integer(effect.objectIds?.[0],'instance ID')>>>0))return 0;
  }
  const o=call(p,'construct'),raw=integer(effect.creatorId,'creator')>>>0,source=call(p,'object',raw);let creator=attached?OBJECT_INVALID:raw,
    cls=0,meta=0,dc=14,feat=65535,spontaneous=0;
  if(source?.objectType===5){creator=raw;
    if(attached&&integer(effect.integers?.[1],'saved caster context')===1){[cls,meta,dc,feat,spontaneous]=effect.integers.slice(2,7);}
    else{cls=integer(source.nativeSpellClass22c,'class')&255;meta=integer(source.nativeSpellMetamagic22d,'metamagic')&255;
      dc=call(p,'saveDC',source,effect.spellId);feat=integer(source.nativeSpellFeat23c,'feat')&65535;spontaneous=integer(source.nativeSpellSpontaneous228,'spontaneous');
      if(attached)effect.integers.splice(1,6,1,cls,meta,dc,feat,spontaneous);
    }
  }else if(source)creator=source.objectType>=5&&source.objectType<=14?raw:OBJECT_INVALID;
  await call(p,'setCreator',o,creator,effect.casterLevel,effect.spellId,cls,meta,dc,feat,spontaneous);
  if(!attached&&(effect.subtype&0x38)===8&&raw!==OBJECT_INVALID&&source&&source.objectType>=5&&source.objectType<=14){
    const owned=ids(source.nativeCreatedAreaEffects170);if(owned.indexOf(o.id)<0)owned.append(o.id);
  }
  await call(p,'load',o,integer(effect.integers?.[0],'VFX persistent row'));
  if(!attached){await call(p,'setDuration',o,effect.durationType&7,effect.duration);await call(p,'setOrientation',o,vector(orientation));}
  for(const [index,key] of ['enter','heartbeat','exit'].entries()){const name=effect.strings?.[index]??'';if(typeof name!=='string')throw new Error('Native area-effect callback is unavailable');if(name.length)o.scripts[key]=name;}
  const area=attached?call(p,'area',target):target;if(attached){await call(p,'setAnchor',o,target.id);position=call(p,'position',target);}
  await call(p,'addToArea',o,area,position,1);if(attached)effect.objectIds[0]=o.id>>>0;return attached?0:undefined;
}
export async function removeAttachedAreaEffect(target,effect,p){
  if(target?.objectType!==5)return;const id=integer(effect.objectIds?.[0],'instance ID')>>>0;
  if(call(p,'object',id))await call(p,'enqueue',11,id,id,0,null);
}
