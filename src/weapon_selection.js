import {OBJECT_INVALID} from './game_object_array.js';
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native weapon selection provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native weapon selection ${n} is unavailable`);return v|0;};
const repo=(o,p)=>required(p,'repository')(o);
const target=(id,p)=>{const object=required(p,'object')(id);return object&&object.objectType>4?object:null;};
const creature=o=>o?.objectType===5?o:null;
const unequip=(o,i,p)=>required(p,'unequip')(o,i,0,1);
const equip=(o,slot,i,p)=>required(p,'equip')(o,slot,i,1,0,1);
const stash=(o,ref,p)=>required(p,'stash')(o,ref,255,255,0,0);
const remove=(o,i,p)=>required(p,'remove')(repo(o,p),i);
const damage=async(o,t,offhand,p)=>(integer(await required(p,'damage')(o,t,offhand,0,0,0,1),'damage')+integer(await required(p,'elemental')(o,creature(t),offhand),'elemental damage'))|0;

// GetRelativeWeaponSize140392fd0. Out-of-range differences return -10;
// ownership mismatch warns but still performs the same arithmetic.
export function relativeWeaponSize(o,item,base,warning){
  if(item.possessorId!==OBJECT_INVALID&&item.possessorId!==o.id){if(typeof warning!=='function')throw new Error('Native relative weapon size warning is unavailable');warning('GetRelativeWeaponSize() on item not in possession of creature, probably wrong usage?');}
  if(!base)throw new Error('Native relative weapon base storage is unavailable');
  const size=((integer(base.weaponSize,'base weapon size')&255)-integer(o.nativeSize718,'creature size'))|0;
  return((size+2)>>>0)<4?size:-10;
}

// EquipMostDamagingMeleeWeapon14038c770. Evaluate temporary native slots,
// retain repository order/tie policy and the one retry with INVALID target.
export async function selectMeleeWeapon(o,targetId,offhand,retry,p){
  targetId=integer(targetId,'target ID')>>>0;offhand=integer(offhand,'offhand');retry=integer(retry,'retry');if(!repo(o,p))return 0;
  const t=target(targetId,p);let slot;
  if(offhand===0){const hand=integer(await required(p,'weaponAttackType')(o),'attack hand');slot=({3:16384,4:32768,5:65536})[hand]??16;}else slot=32;
  const old={item:required(p,'equipped')(o,slot)};let best=null;
  if(old.item&&required(p,'baseInfo')(old.item).ranged!==0){await unequip(o,old.item,p);await stash(o,old,p);old.item=null;}
  if(offhand===1&&!old.item){const right=p.equipped(o,16);if(right&&p.baseInfo(right).weaponWield===8){slot=16;old.item=right;}}
  if(old.item){await unequip(o,old.item,p);await stash(o,old,p);}
  let score=await damage(o,t,0,p);const monk=integer(await required(p,'monkAbilities')(o),'monk abilities');
  for(let node=repo(o,p).head;node;node=node.next){
    const item=required(p,'item')(node.id),base=item?p.baseInfo(item):null;if(!item||!base||base.weaponType===0)continue;
    const ref={slot},size=integer(await required(p,'relativeSize')(o,item),'relative weapon size'),allowed=integer(await required(p,'canEquip')(o,item,ref,0,0,1),'equip gate')&255;
    if((offhand===0?allowed===0:allowed!==1)||base.ranged!==0||offhand!==0&&(size>=1||size===-10))continue;
    await equip(o,ref.slot,item,p);const value=await damage(o,t,offhand,p);
    if(value>score||value===score&&monk===0){score=value;best=item;}
    await unequip(o,item,p);
  }
  if(old.item){await remove(o,old.item,p);await equip(o,slot,old.item,p);}
  if(!best){
    if(!old.item)return Number(monk!==0);
    if(targetId!==OBJECT_INVALID&&retry===0)return selectMeleeWeapon(o,OBJECT_INVALID,offhand,1,p);
    if(monk!==0&&retry!==0){await unequip(o,old.item,p);await stash(o,old,p);return 1;}
  }else if(!old.item||old.item.id!==best.id){const result=integer(await required(p,'addEquip')(o,best,slot,0,0,OBJECT_INVALID),'queued equip result');return Number(result!==0);}
  return 1;
}

// EquipMostDamagingRangedWeapon14038cc50. This build compares the native
// GetAttackModifierVersus result (including counter mutations), not damage.
export async function selectRangedWeapon(o,targetId,p){
  targetId=integer(targetId,'target ID')>>>0;if(!repo(o,p))return 0;const t=creature(target(targetId,p)),old={item:required(p,'equipped')(o,16)};
  let best=null,score=-30;
  if(old.item){const base=required(p,'baseInfo')(old.item);if(base&&base.ranged>0){best=old.item;score=integer(await required(p,'attackModifier')(o,t),'attack modifier');}
    await unequip(o,old.item,p);await stash(o,old,p);
  }
  for(let node=repo(o,p).head;node;node=node.next){
    const item=required(p,'item')(node.id),base=item?p.baseInfo(item):null;if(!item||!base||base.weaponType===0)continue;
    const ref={slot:16};if((integer(await required(p,'canEquip')(o,item,ref,0,0,1),'equip gate')&255)===0||base.ranged<=0)continue;
    await equip(o,ref.slot,item,p);const value=integer(await p.attackModifier(o,t),'attack modifier');if(value>score){score=value;best=item;}await unequip(o,item,p);
  }
  if(old.item){await remove(o,old.item,p);await equip(o,16,old.item,p);}
  if(!best)return 0;
  if(old.item!==best){if(old.item){await unequip(o,old.item,p);await stash(o,old,p);}await remove(o,best,p);await equip(o,16,best,p);}
  const result=integer(await required(p,'ammunition')(o,targetId,best),'ammunition result');
  if(old.item!==best){await unequip(o,best,p);const ref={item:best};await stash(o,ref,p);best=ref.item;
    if(old.item){await remove(o,old.item,p);await equip(o,16,old.item,p);}
  }
  if(result===1&&old.item!==best)await required(p,'addEquip')(o,best,16,0,0,OBJECT_INVALID);
  return result;
}

// EquipMostDamagingAmmunition14038c390. RangedWeapon BYTE is the candidate
// base-item ID; native launcher-slot constants and strictly-better ties stay.
export async function selectAmmunition(o,targetId,launcher,p){
  if(!repo(o,p))return 0;const t=target(integer(targetId,'target ID')>>>0,p),baseId=integer(launcher.baseItem,'launcher base')>>>0;let slot=0;
  if(baseId===8||baseId===11)slot=2048;else if(((baseId-6)>>>0)<2)slot=8192;else if(baseId===61)slot=4096;
  else if(baseId<64&&(0x8800000080000000n>>BigInt(baseId)&1n)!==0n)slot=16;
  else await required(p,'warning')('OH MY GOD! Attempting to get ammo for an invalid launcher.');
  const old={item:required(p,'equipped')(o,slot)};let best=old.item,score=-30;
  if(old.item){score=await damage(o,t,0,p);await unequip(o,old.item,p);await stash(o,old,p);}
  for(let node=repo(o,p).head;node;node=node.next){
    const item=required(p,'item')(node.id);if(!item||!p.baseInfo(item))continue;
    const launcherBase=required(p,'baseInfo')(launcher);if(!launcherBase)throw new Error('Native launcher base storage is unavailable');
    if((item.baseItem>>>0)!==(launcherBase.ranged&255))continue;
    const ref={slot};if((integer(await required(p,'canEquip')(o,item,ref,0,0,1),'equip gate')&255)===0)continue;
    await equip(o,ref.slot,item,p);const value=await damage(o,t,0,p);if(value>score){score=value;best=item;}await unequip(o,item,p);
  }
  if(old.item){await remove(o,old.item,p);await equip(o,slot,old.item,p);}
  if(!best)return 0;
  if(!old.item||old.item.id!==best.id)await required(p,'addEquip')(o,best,slot,0,0,OBJECT_INVALID);
  return 1;
}

// ExecuteCommandActionEquipMostDamagingMelee14050d940/ranged14050d9d0.
// The ranged wrapper falls back to primary melee only on result==0.
export async function scriptSelectWeapon(o,targetId,offhand,ranged,p){
  if(!o)return;
  if(ranged){if(await selectRangedWeapon(o,targetId,p)===0)await selectMeleeWeapon(o,targetId,0,0,p);}
  else await selectMeleeWeapon(o,targetId,offhand,0,p);
}
