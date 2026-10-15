import {getAttackData,copyAttackData} from './combat_attack_data.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {intEntry} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native safe projectile ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native safe projectile provider ${n} is unavailable`);return p[n];};
// ResolveSafeProjectile1403ebab0 captures an attack metadata copy without
// strings or effect/message lists. Native event21 targets/calls the attacker.
export async function resolveSafeProjectile(actor,delay,index,p){
  delay=integer(delay,'delay')>>>0;index=integer(index,'attack index')>>>0;
  const ai=await required(p,'aiMaster')(),data=getAttackData(actor.combatRound,index,p.warning);
  const weapon=await required(p,'equippedItem')(actor,16);if(!weapon)return;
  const base=integer(await required(p,'baseItem')(weapon),'base item');await required(p,'baseItemInfo')(base);
  const slot=[8,11].includes(base)?2048:[6,7].includes(base)?8192:base===61?4096:16;
  const ammo=await p.equippedItem(actor,slot);
  if(!ammo)required(p,'warning')('Native ResolveSafeProjectile ammunition item is NULL');
  data.raw.setUint32(0x8c,ammo?integer(ammo.id,'ammunition ID')>>>0:OBJECT_INVALID,true);
  await required(p,'enqueue')(ai,21,actor.id,actor.id,delay,copyAttackData(data,0));
}

// Creature event21,14038e629..14038e94b. Resolve captured ammo ID at
// release time, but read the caller's CURRENT position/right-hand base item.
export async function receiveSafeProjectile(actor,callerId,data,rules,p){
  if(!data)return;
  const caller=await required(p,'creature')(callerId>>>0);
  if(!caller){required(p,'warning')('Native warning: Invalid caller creature for broadcast safe projectile!');return;}
  const ammunitionId=data.raw.getUint32(0x8c,true),ammo=await required(p,'item')(ammunitionId);
  if(ammunitionId===OBJECT_INVALID)required(p,'warning')('Native warning: Invalid Ammunition Specified!');
  if(!ammo)return;
  let damageType=12;
  for(const type of [16,17,18,19]){
    const property=await required(p,'property')(ammo,type,0);
    if(property){
      damageType=(property.PropertyName&65535)===16?property.Subtype&65535:property.CostValue&255;
      if(damageType>2)damageType=(damageType-2)|0;
      break;
    }
  }
  if(!rules.damagetypes)throw new Error('Native ranged projectile damagetypes table is unavailable');
  const row=intEntry(rules.damagetypes,damageType,'DamageRangedProjectile');let appearance=0;
  if(row.found){if(((row.value-6)>>>0)>1)appearance=row.value&255;}
  else appearance=({4:1,5:2,7:3,8:4,11:5})[damageType]??0;
  await required(p,'broadcast')(actor,{sourceId:callerId>>>0,targetId:data.targetId,
    from:await required(p,'position')(caller),to:[0x80,0x84,0x88].map(n=>data.raw.getFloat32(n,true)),
    duration:data.reactionDelay,appearance,flags:0,result:data.result,deflection:data.deflected===1?13:0});
}

// BroadcastSafeProjectile14048f270..14048f544. Live area spatial IDs,
// real attached clients, inclusive 3D distance to EITHER endpoint. Internal
// recipient records are deliberately separate from NWN wire encoding.
export async function broadcastSafeProjectile(actor,data,p){
  const caller=await required(p,'creature')(data.sourceId);let baseItem=255;
  if(caller){const weapon=await required(p,'equippedItem')(caller,16);if(weapon)baseItem=integer(await required(p,'baseItem')(weapon),'broadcast base item')&255;}
  const area=await required(p,'area')(actor);if(!area)return;
  const range=actor.nativeProjectileRange268;if(!Number.isFinite(range))throw new Error('Native projectile broadcast range is unavailable');
  const f=Math.fround,radius=f(f(range)*f(range));
  const near=(position,end)=>{const delta=position.map((v,i)=>f(f(v)-f(end[i])));return f(f(f(delta[1]*delta[1])+f(delta[0]*delta[0]))+f(delta[2]*delta[2]))<=radius;};
  for(let index=0;;index++){
    const ids=await required(p,'areaIds')(area);if(ids===null)return;if(!Array.isArray(ids)&&!(ids instanceof Uint32Array))throw new Error('Native projectile area IDs are unavailable');
    if(index>=ids.length)return;
    const viewer=await p.creature(ids[index]);if(!viewer)continue;
    const client=await required(p,'client')(viewer.id);if(!client)continue;
    const position=await required(p,'position')(viewer);
    if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Native projectile recipient position is unavailable');
    if(near(position,data.from)||near(position,data.to))await required(p,'send')(client,{...structuredClone(data),baseItem});
  }
}
