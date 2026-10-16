import {OBJECT_INVALID} from './game_object_array.js';
import {actionParameter} from './object_actions.js';
import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item cast ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native item cast provider ${n} is unavailable`);return p[n](...args);};

// AIActionItemCastSpell1403c07b0..1403c1a27. The action owns its saved
// world-time slots and resource consumption; class spell slots are untouched.
export async function executeItemCast(actor,node,rules,p){
 await call(p,'activityManager',actor,1);
 const itemId=actionParameter(node,0)>>>0,index=actionParameter(node,1)|0,variant=actionParameter(node,2)|0,targetId=actionParameter(node,3)>>>0,
  point=[4,5,6].map(i=>actionParameter(node,i));
 if(node.parameterData[7]===0&&node.parameterData[8]===0){
  // Native overwrites only the low DWORDs of these already allocated slots;
  // AddActionNodeParameter would incorrectly change the node's count/types.
  const time=call(p,'worldTime',actor);node.parameterData[7]=integer(time.day,'start day')>>>0;node.parameterData[8]=integer(time.time,'start time')>>>0;
 }
 const then={day:actionParameter(node,7)>>>0,time:actionParameter(node,8)>>>0},consume=actionParameter(node,9)|0;
 actor.nativeAttackField748=6000;
 const cleanup=async status=>{await call(p,'setAnimation',actor,0);actor.nativeField828=0;await call(p,'removeRoundSpell',actor);await call(p,'pendingEquipment',actor);return status;};
 if(await call(p,'dead',actor)===1||await call(p,'dying',actor)===1)return cleanup(3);
 const target=call(p,'object',targetId);
 if(targetId!==OBJECT_INVALID&&!target)return cleanup(3);
 actor.nativeTarget740=targetId===OBJECT_INVALID?integer(actor.areaId,'area ID')>>>0:targetId;
 const creature=target?call(p,'asCreature',target):null,item=call(p,'item',itemId);
 if(!item)return cleanup(3);
 const property=call(p,'activeProperty',item,index);if(!property)return cleanup(3);
 let id=call(p,'propertyInt',property.subtype&65535,'SpellIndex')>>>0,spell=call(p,'spell',id);
 if(!spell)return cleanup(3);
 if((call(p,'subRadialCount',spell)&255)>0){id=call(p,'subRadialSpell',spell,variant&255)>>>0;spell=call(p,'spell',id);if(!spell)return cleanup(3);}
 const elapsed=integer(call(p,'elapsed',call(p,'worldTime',actor),then),'elapsed time')>>>0,
  model=call(p,'modelType',actor),humanoid=model.includes('P')||model.includes('F'),base=integer(item.baseItem,'base item');
 node.nativeField9c=0;
 let release,total,animation;
 if(base===49||base===104){release=750;total=1500;animation=humanoid?70:1;}
 else if(base===54||base===75){release=2500;total=(integer(spell.castTime,'cast time')+2500)>>>0;animation=elapsed<2000?humanoid?71:1:17;}
 else{release=500;total=(integer(spell.castTime,'cast time')+500)>>>0;animation=base===81?10:17;}
 if(integer(Number(actor.combatRound.started),'round started')===0){
  // Native hash starts with the precomputed 'F' seed, then hashes AST_... .
  await call(p,'startRound',actor,base===49||base===104?rulesetInt(rules,'FAST_SPELLCAST_ROUND',3000)>>>0:6000);
  await call(p,'decrementRound',actor,total,0);await call(p,'pause',actor,1,actor.id);await call(p,'pauseTimer',actor,total,0);
 }
 if(integer(actor.nativeField828,'item activation flag')===0){
  if([49,54,104].includes(base)&&(call(p,'playerCharacter',actor)===0||call(p,'difficulty',2)===0))await call(p,'opportunity',actor,OBJECT_INVALID,0);
  actor.nativeField828=1;
 }
 const prepare=async released=>{
  actor.nativeSpellId218=id;actor.nativeSpellFeat23c=65535;actor.nativeSpellTarget214=targetId;actor.nativeSpellPoint208=[...point];
  actor.nativeSpellImpact224=0;actor.nativeSpellSpontaneous228=0;actor.nativeSpellTarget818=itemId;actor.nativeSpellMetamagic22d=0;actor.nativeCasterOverride820=released;
  await call(p,'projectileTime',actor,0);
  if(!released)item.nativePriceDirty398=1;
  actor.nativeCasterOverride824=call(p,'propertyInt',property.subtype&65535,'CasterLvl')|0;
  await call(p,'setAnimation',creature&&creature.masterId===actor.id&&(base===49||base===104)?creature:actor,animation);
 };
 if(elapsed<release){
  if((call(p,'usesLeft',item,index&255)&65535)<1&&property.costValue!==13&&property.costValue!==7){await cleanup(3);await call(p,'feedback',actor,23);return 3;}
  await prepare(0);return 1;
 }
 if(integer(actor.nativeSpellImpact224,'impact flag')===0){
  await prepare(1);await call(p,'impact',actor,id,point,targetId,255,itemId,0,0,0,0);
  if(integer(Number(actor.combatRound.started),'round started')===1)await call(p,'removeSpellActions',actor);
  if(consume!==0){
   const cost=integer(property.costValue,'property cost')&65535;let destroy=false,charged=false;
   if(cost===1){if(integer(item.stackSize,'stack size')>1)item.stackSize=(item.stackSize-1)|0;else{property.remaining=0;destroy=integer(item.plot,'plot flag')===0;}}
   else if(cost>=2&&cost<=6){charged=true;const amount=7-cost;if(integer(item.charges,'charges')>=amount)await call(p,'setCharges',item,(item.charges-amount)|0,1);}
   else if(cost>=8&&cost<=12){let uses=integer(property.usesPerDay,'daily uses')&255;if(uses>0)property.usesPerDay=--uses;if(uses<1)property.remaining=0;}
   if(integer(property.remaining,'property readiness')===0){
    let depleted=[49,54,75,104].includes(base);
    if(!depleted&&charged){
     depleted=true;
     for(let n=0;n<call(p,'propertyCount',item);n++){
      const other=call(p,'activeProperty',item,n);
      if(other&&(other.type&65535)===15&&(other.costValue&65535)>=2&&(other.costValue&65535)<=6&&other.remaining!==0){depleted=false;break;}
     }
    }
    if(depleted&&integer(item.plot,'plot flag')===0)destroy=true;
   }
   if(destroy)await call(p,'enqueue',11,actor.id,item.id,(integer(actor.nativeSpellProjectileTime220,'projectile time')+500)>>>0,null);
   else await call(p,'activeChanged',item,0);
  }
 }
 return elapsed<total?1:cleanup(2);
}

// ClearAction1403870b0 item46 branch251..289 and shared tail79a..7ca.
export async function clearItemCast(actor,node,head,p){
 if(integer(node.nativeField9c,'interruptible flag')===0)return 0;
 actor.spellActionTargetId=actor.nativeTarget740=OBJECT_INVALID;await call(p,'removeSpellActions',actor);
 await call(p,'setAnimation',actor,0);actor.nativeField828=0;await call(p,'pendingEquipment',actor);
 if(actor.lockOrientationId!==OBJECT_INVALID)await call(p,'setLock',actor,OBJECT_INVALID);
 if(head===1)actor.objectActionState.startDay=actor.objectActionState.startTime=0;return 1;
}
