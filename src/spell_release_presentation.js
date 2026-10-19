import {OBJECT_INVALID} from './game_object_array.js';
import {nativeDistanceSquared} from './nearest_objects.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell presentation ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p[n]!=='function')throw new Error(`Native spell presentation provider ${n} is unavailable`);return p[n](...args);};
const vector=(v,n)=>{if(!Array.isArray(v)||v.length!==3||!v.every(x=>typeof x==='number'))throw new Error(`Native spell presentation ${n} is unavailable`);return v.map(f);};

// BroadcastSpellData14048f550..14048f8b4. Reset payload INTs before
// EVERY physical area entry, even entries that cannot receive the message.
export async function broadcastSpellData(actor,spell,data,p){
 const areaObject=call(p,'object',integer(actor.areaId,'area ID')>>>0);if(!areaObject||!call(p,'asArea',areaObject))return;
 const caster=call(p,'creature',actor.id);if(caster&&await call(p,'dm',caster)!==0)return;
 const area=call(p,'area',actor);if(!area)throw new Error('Native spell release broadcast area is unavailable');
 for(let i=0;i<call(p,'ids',area).length;i++){
  data.integers[1]=data.integers[2]=data.integers[3]=0;
  const viewer=call(p,'creature',call(p,'ids',area)[i]);if(!viewer)continue;
  const node=call(p,'visibility',viewer,actor.id);if(node===null||(integer(node,'visibility')&1)===0)continue;
  const client=call(p,'client',viewer.id);if(!client||!(nativeDistanceSquared(viewer.position,actor.position)<=900))continue;
  if(call(p,'asCreature',actor)){
   const itemId=integer(data.objects[1],'item ID')>>>0;
   if(itemId===OBJECT_INVALID){data.integers[1]=Number(await call(p,'identified',actor,viewer.id)===1);}
   else{
    const item=call(p,'item',itemId);
    if(item){
     const ownerId=integer(item.ownerId,'item possessor')>>>0,owner=call(p,'creature',ownerId);if(owner&&await call(p,'dm',owner)!==0)return;
     if(ownerId===(actor.id>>>0))data.integers[1]=1;
     else{
      const container=call(p,'item',ownerId);
      if(container){if((integer(container.ownerId,'container possessor')>>>0)===(actor.id>>>0))data.integers[1]=1;}
      else{const owner=call(p,'creature',ownerId);if(owner&&(integer(owner.masterId,'owner master')>>>0)===(actor.id>>>0))data.integers[1]=1;}
     }
     data.integers[3]=integer(item.baseItem,'base item');
    }
   }
  }
  await call(p,'send',client,8,structuredClone(data));
 }
}

// SpellCastAndImpact14049c570..14049c646: source identity can be an
// associate using the master's creature weapon (base49/104), without changing
// the broadcast owner or event8's canonical caster/caller.
export function spellReleaseData(actor,spell,itemId,targetId,p){
 const data={objects:[actor.id>>>0,itemId>>>0],integers:[spell.id|0]};
 const target=call(p,'creature',targetId>>>0);
 if(target&&(integer(target.masterId,'target master')>>>0)===(actor.id>>>0)){
  const item=call(p,'item',itemId>>>0);if(item&&[49,104].includes(integer(item.baseItem,'base item')))data.objects[0]=targetId>>>0;
 }
 return data;
}
export async function broadcastSpellRelease(actor,spell,itemId,targetId,p){return broadcastSpellData(actor,spell,spellReleaseData(actor,spell,itemId,targetId,p),p);}

// SpellCastAndImpact14049c646..14049c843. Creature endpoint uses its
// release-time position; other targets use the caster's stored cast point.
// Equipped/repository items suppress projectiles, including nested containers.
export async function releaseSpellProjectile(actor,spell,targetId,path,p){
 let from=vector(call(p,'position',actor),'origin');
 if(integer(actor.animationState,'animation')===10){const direction=vector(actor.orientation,'orientation');from=from.map((v,i)=>f(v+f(direction[i]*f(.4))));from[2]=f(from[2]+f(.6));}
 const target=call(p,'creature',targetId>>>0);let to;
 if(target)to=vector(call(p,'position',target),'target position');
 else{
  const item=call(p,'item',targetId>>>0);
  if(item&&call(p,'asCreature',actor)){
   if(await call(p,'equipped',actor,item)!==0||await call(p,'repository',actor,item,1)!==0)return;
  }
  to=vector(actor.nativeSpellPoint208,'stored cast point');
 }
 path=integer(path,'projectile path')&255;
 await call(p,'broadcastProjectile',actor,{sourceId:actor.id>>>0,targetId:targetId>>>0,from,to,duration:integer(actor.nativeSpellProjectileTime220,'travel time')>>>0,appearance:path!==0?7:6,flags:spell.id|0,result:0,deflection:path});
}
