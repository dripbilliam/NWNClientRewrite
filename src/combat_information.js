import {abilityModifierCells} from './ability_modifier_cache.js';
import {OBJECT_INVALID} from './game_object_array.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native combat information ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native combat information provider ${n} is unavailable`);return p[n](...a);};
const at=(e,i)=>integer(e.integers?.[i]??0,`effect INT${i}`),type=e=>integer(e.type,'effect type')&65535;
const i8=n=>(n<<24)>>24;
const copiedScalars=[...Array.from({length:16},(_,i)=>i),19,20,24,25,26,27,28,29];

// Complete GetFilteredEffectList140390560..140390b56. Results contain the
// original records, not copies or merged IDs. The actor owns the sorted source
// and its cached start index; rank comes from active iprp_damagecost.
export function filteredCombatEffects(effects,kind,start,rank){
  kind=integer(kind,'filter kind')&255;start=integer(start,'filter start')&65535;
  if(kind!==1&&kind!==2)return[];
  const first=kind===1?10:13,last=first+1,result=[];
  for(let index=start;index<effects.length;index++){
    const effect=effects[index],t=type(effect);if(t>last)break;if(t!==first&&t!==last)continue;
    const same=result.findIndex(e=>type(e)===t&&Array.from({length:kind===1?4:5},(_,i)=>i+1).every(i=>at(e,i)===at(effect,i))&&
      (integer(e.spellId,'spell ID')===-1||integer(effect.spellId,'spell ID')===-1||e.spellId===effect.spellId));
    if(same>=0){if((kind===1?at(result[same],0):rank(at(result[same],0)))<(kind===1?at(effect,0):rank(at(effect,0))))result[same]=effect;}
    else result.push(effect);
  }
  return result;
}

// Native CCombatInformation scalar fields and independently owned node arrays.
// Pointer slots/padding are not fabricated memory addresses. Constructor2a22b0
// initializes these fields; node constructor2a2370 sets race BYTE5 to28.
export function createCombatInformation(){
  const scalars=new Uint8Array(32);scalars[8]=1;scalars[9]=3;scalars[20]=2;scalars[29]=2;
  const initialized=new Uint8Array(32);for(const index of copiedScalars)initialized[index]=1;
  return{scalars,initialized,weaponIds:[OBJECT_INVALID,OBJECT_INVALID],attackNodes:[],damageNodes:[],attackCapacity:0,damageCapacity:0,text:['',''],flags:0};
}
// JS owns these arrays rather than allocating native heap pointers. Releasing
// the owner invalidates its nodes/text; it never touches game-object identity.
export function disposeCombatInformation(cache){
  for(const list of [cache.attackNodes,cache.damageNodes])while(list.length){const entry=list.shift();if(entry!==null)entry.disposed=true;}
  cache.disposed=true;cache.text=['',''];cache.attackCapacity=cache.damageCapacity=0;
}
function copyScalars(target,source){
  for(const index of copiedScalars){target.scalars[index]=source.scalars[index];target.initialized[index]=source.initialized[index];}
  target.weaponIds[0]=source.weaponIds[0];target.weaponIds[1]=source.weaponIds[1];
}
// Copy constructor1402a2120: selected scalars/weapon IDs, both strings and
// two damage dice/die bytes (the shared `flags` WORD at+68). It leaves the
// new node arrays EMPTY;16..18 are not copied.
export function copyCombatInformation(source){
  const result=createCombatInformation();copyScalars(result,source);result.text=[...source.text];result.flags=integer(source.flags,'flags')&65535;return result;
}
// Assignment1402a2cd0: self-assignment no-op; copies selected scalars and
// deep-copies nodes with16/doubling capacity. It retains destination strings
// and flags. Native releases old pointer arrays without deleting their nodes.
export function assignCombatInformation(target,source){
  if(target===source)return target;copyScalars(target,source);
  target.attackNodes=[];target.damageNodes=[];target.attackCapacity=target.damageCapacity=0;
  for(const kind of ['attack','damage'])for(const entry of source[kind+'Nodes']){
    if(entry===null)throw new Error('Native combat assignment dereferences a null source node');
    append(target,kind,new Uint8Array(entry));
  }
  return target;
}
const sameScalars=(a,b)=>copiedScalars.every(i=>a.scalars[i]===b.scalars[i])&&a.weaponIds.every((id,i)=>id===b.weaponIds[i]);
// These original overloads are deliberately NOT complements: ==1402a2fd0
// compares node pointer identities; !=1402a31c0 compares six-byte node VALUES.
// Both ignore strings, flags, capacities and scalar16..18/padding.
export function combatInformationEqual(a,b){return Number(sameScalars(a,b)&&['attack','damage'].every(kind=>a[kind+'Nodes'].length===b[kind+'Nodes'].length&&a[kind+'Nodes'].every((node,i)=>node===b[kind+'Nodes'][i])));}
export function combatInformationDifferent(a,b){
  if(!sameScalars(a,b))return 1;
  for(const kind of ['attack','damage']){
    const left=a[kind+'Nodes'],right=b[kind+'Nodes'];if(left.length!==right.length)return 1;
    for(let index=0;index<left.length;index++){
      if(left[index]===null||right[index]===null)throw new Error('Native combat node comparison dereferences a null node');
      if(left[index].some((value,i)=>value!==right[index][i]))return 1;
    }
  }
  return 0;
}
// AIUpdate14037caac..14037caf8. Re-read dirty/consumer state after spell
// callbacks; the two flags are cleared only after their respective work.
export function refreshDirtyCreatureStats(actor,p){
  if(actor.nativeField544===1){call(p,'memorized',actor);call(p,'spellUses',actor);actor.nativeField544=0;}
  if(actor.combatInformationDirty===1&&integer(actor.nativeField540,'combat consumers')>0){call(p,'combat',actor);actor.combatInformationDirty=0;}
}
const node=()=>Uint8Array.of(0,0,0,0,0,28);
function append(cache,kind,value){const list=cache[kind+'Nodes'],key=kind+'Capacity';if(list.length===cache[key])cache[key]=cache[key]===0?16:cache[key]*2;list.push(value);}
function restrictions(n,e){if(at(e,2)!==28)n[5]=at(e,2);if(at(e,3)!==0)n[3]=at(e,3);if(at(e,4)!==0)n[4]=at(e,4);}
function hand(n,selector,attack){
  // Native attack branch compares selector3 THREE times;4/5 retain default0.
  const value=selector===0?6:selector===1?1:selector===2?2:selector===7?7:selector===3?3:!attack&&selector===4?4:!attack&&selector===5?5:0;n[2]=value;
}

// Complete UpdateCombatInformation1404171e0..140418522 orchestration. Lower
// stat/item queries are explicit providers, separately validated from this owner.
export function updateCombatInformation(actor,p){
  if(actor.nativeCombatInformationD70==null)throw new Error('Native combat-information constructor storage is unavailable');
  call(p,'dispose',actor.nativeCombatInformationD70);actor.nativeCombatInformationD70=call(p,'create');
  const cache=actor.nativeCombatInformationD70,s=cache.scalars;
  for(let i=0;i<6;i++)actor[abilityModifierCells[i]]=integer(call(p,'modifier',call(p,'score',actor,i)),'ability modifier')&255;
  for(const e of call(p,'filtered',actor,1)){
    const selector=at(e,1);if(![0,1,2,3,4,5,7].includes(selector))continue;
    const n=node();n[0]=type(e)===10?at(e,0):-at(e,0);hand(n,selector,true);restrictions(n,e);append(cache,'attack',n);
  }
  for(const e of call(p,'filtered',actor,2)){
    const selector=at(e,5);if(![0,1,2,3,4,5,7].includes(selector))continue;
    const n=node();n[0]=type(e)===13?at(e,0):-at(e,0);const flags=at(e,1)>>>0;n[1]=flags<8?(flags===2?1:flags===4?2:flags===1?0:12):call(p,'damageIndex',flags);hand(n,selector,false);restrictions(n,e);append(cache,'damage',n);
  }
  let monk=call(p,'monk',actor)!==0;
  if(monk){const right=call(p,'equipped',actor,16),left=call(p,'equipped',actor,32);if(right&&(call(p,'base',right).monk!==1||left&&call(p,'base',left).monk===0))monk=false;}
  const bab=integer(call(p,'baseAttack',actor,1),'base attack'),adjusted=(bab+(monk?2:4))|0;
  let attacks=adjusted<(monk?18:30)?Math.trunc(adjusted/(monk?3:5)):6;s[0]=attacks===0?1:attacks;
  const right=call(p,'equipped',actor,16);
  if(right&&call(p,'base',right).ranged!==0&&call(p,'base',right).weaponWield!==11){
    const ammoBase=call(p,'baseById',call(p,'base',right).ranged&255),ammo=call(p,'equipped',actor,ammoBase.equipableSlots);
    if(ammo){
      for(const property of call(p,'passive',ammo))if(property)property.remaining=1;
      const properties=call(p,'passive',ammo);
      for(let i=0;i<properties.length;i++){
        const a=properties[i],t=a.type&65535;if(t!==16&&t!==17&&t!==18&&t!==19&&t!==21)continue;
        let damage=t===21?call(p,'damageIndex',call(p,'damageFlags',right)):t===16?a.subtype&65535:a.param1Value&255;if(t!==21&&damage>2)damage-=2;
        for(let j=0;j<properties.length;j++)if(j!==i){const b=properties[j];if(b.remaining===1&&b.type===a.type&&b.subtype===a.subtype&&b.param1Value===a.param1Value&&
          (t===21?(a.costValue&65535)<(b.costValue&65535):call(p,'rank',a.costValue&65535)<call(p,'rank',b.costValue&65535)))a.remaining=0;}
        if(a.remaining===1){
          const n=node();n[0]=t===21?-(a.costValue&65535):a.costValue&65535;n[1]=damage;n[2]=1;
          if(t===18)n[5]=a.subtype;
          if(t===17){if((a.subtype&65535)<4)n[3]=a.subtype;else n[4]=a.subtype;}
          if(t===19){const subtype=a.subtype&65535;n[3]=subtype<3?2:subtype<6?1:3;n[4]=[0,3,6].includes(subtype)?4:[1,4,7].includes(subtype)?1:5;}
          append(cache,'damage',n);
        }
      }
      for(const property of call(p,'passive',ammo))if(property)property.remaining=0;
    }
  }
  const left=call(p,'equipped',actor,32);
  if(left){if(![14,56,57].includes(left.baseItem)&&call(p,'base',left).weaponType!==0){s[24]=1;cache.weaponIds[1]=left.id>>>0;}}
  else if(right&&call(p,'base',right).weaponWield===8){s[24]=1;cache.weaponIds[1]=right.id>>>0;}
  const ranged=right&&call(p,'base',right).ranged!==0;
  s[1]=ranged?call(p,'rangedAttack',actor,0,0):call(p,'meleeAttack',actor,0,0,0);
  s[2]=ranged?call(p,'rangedDamage',actor):call(p,'meleeDamage',actor,0,255);cache.weaponIds[0]=right?right.id>>>0:OBJECT_INVALID;
  if(s[24]===1){s[3]=call(p,'meleeAttack',actor,1,0,0);s[4]=call(p,'meleeDamage',actor,1,255);}
  s[6]=Math.max(0,Math.min(100,i8((integer(actor.nativeArcaneChestD79,'chest failure')+integer(actor.nativeArcaneShieldD7a,'shield failure'))&255)+i8(integer(actor.nativeArcaneEffectD78,'effect failure'))));
  s[5]=call(p,'spellResistance',actor);const penalties=call(p,'armorPenalties',actor);s[7]=-(i8(penalties[0])+i8(penalties[1]));
  s[8]=call(p,'unarmedDice',actor);s[9]=call(p,'unarmedDie',actor);
  for(let i=0;i<3;i++){
    const slot=16384<<i;
    for(const [column,offset]of [['NumDice',10],['Die',13]]){
      const item=call(p,'equipped',actor,slot),property=item&&call(p,'propertyExists',item,77,0)===1?call(p,'property',item,77,0):null;
      s[offset+i]=property&&(property.costValue&65535)!==0?call(p,'monsterCost',property.costValue&65535,column):0;
    }
    s[16+i]=call(p,'meleeDamage',actor,0,i);cache.initialized[16+i]=1;
  }
  const criticalItem=call(p,'equipped',actor,16);let multiplier=criticalItem?call(p,'base',criticalItem).criticalMultiplier&255:2;
  if(criticalItem&&call(p,'hasStoredFeat',actor,883)!==0){const base=call(p,'base',criticalItem);if(base&&call(p,'hasFeat',actor,base.weaponOfChoice&65535)!==0)multiplier++;}
  s[20]=multiplier;s[19]=21-call(p,'criticalRoll',actor,0);s[29]=call(p,'criticalMultiplier',actor,1);s[28]=21-call(p,'criticalRoll',actor,1);
  return cache;
}
