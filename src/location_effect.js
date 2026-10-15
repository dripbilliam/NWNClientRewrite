import {visualTransform} from './visual_effect.js';
import {updateLinked} from './linked_effect.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native location effect ${n} is unavailable`);return v|0;};
const vector=(v,n)=>{if(!Array.isArray(v)||v.length!==3||v.some(x=>typeof x!=='number'))throw new Error(`Native location effect ${n} is unavailable`);return v.map(f);};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native location effect provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandApplyEffectAtPoint140510710 delegates only to an existing
// area. The area owner14035bdf0 admits AoE31, beam6, visual30 and link40;
// all other effect types are consumed without applying to nearby objects.
export async function applyLocationEffect(durationType,value,location,seconds,p){
  if(!value||!location)throw new Error('Native location effect VM structure is unavailable');
  const effect=structuredClone(value),duration=integer(durationType,'duration');effect.durationType=duration===0?0:duration===1?1:2;
  if(duration===1){if(typeof seconds!=='number')throw new Error('Native location effect duration FLOAT is unavailable');effect.duration=f(seconds);}
  const area=call(p,'object',integer(location.areaId,'area ID')>>>0);if(area?.objectType!==4)return;
  return call(p,'applyArea',area,effect,vector(location.position,'position'),vector(location.nativeOrientation,'orientation'));
}
export async function applyAreaEffect(area,effect,position,orientation,p){
  const type=integer(effect.type,'type')&65535;
  if(type===31){await call(p,'areaEffect',area,effect,position,orientation);return;}
  if(type===6){const source=call(p,'object',integer(effect.creatorId,'beam creator')>>>0);if(source?.objectType!==5)return;
    effect.objectIds[0]=area.id>>>0;position.forEach((v,i)=>effect.floats[i]=f(v));await call(p,'applyObject',source,effect);return;}
  if(type===30){await broadcastLocationVisual(area,effect,position,p);return;}
  if(type!==40)return;
  updateLinked(effect,0,p);
  for(const key of ['linkLeft','linkRight'])if(effect[key])await applyAreaEffect(area,effect[key],position,orientation,p);
  effect.linkLeft=null;effect.linkRight=null;updateLinked(effect,0,p);
}
// CNWSArea::PlayVisualEffect140364670. Point visuals use active RADIUS+45,
// an early upper-X exit and the area list's actual client recipients. They
// have no native duration/source/target argument in SendAreaVisualEffect.
export async function broadcastLocationVisual(area,effect,position,p){
  position=vector(position,'broadcast point');const visualId=integer(effect.integers?.[0],'visual ID')&65535,transform=visualTransform(effect),
    radius=f(f(call(p,'visualRadius',visualId))+f(45)),low=f(position[0]-radius),high=f(position[0]+radius),first=call(p,'firstByX',area,low);
  if(first===null)return;
  for(let index=first;;index++){
    const ids=call(p,'areaIds',area);if(index>=ids.length)return;
    const object=call(p,'object',ids[index]);if(!object||object.objectType<=4)continue;
    const point=vector(call(p,'position',object),'viewer position');if(point[0]>high)return;
    const client=call(p,'client',object.id);if(!client)continue;
    const delta=point.map((n,i)=>f(n-position[i])),distance=f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]));
    if(!(distance<=f(radius*radius)))continue;
    await call(p,'send',client,{visualId,position:[...position],transform:structuredClone(transform)});
  }
}
