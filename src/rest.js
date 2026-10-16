import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native rest ${n} is unavailable`);return v|0;};
const u32=(v,n)=>integer(v,n)>>>0;
const timers=['nativeRestHealInterval854','nativeRestMissingHP858','nativeRestSpellInterval85c','nativeRestSpellCursor860'];
export function initializeRestState(o){for(const field of [...timers,'nativeRestStartDayAd8','nativeRestStartTimeAdc','nativeRestEnemyDay558','nativeRestEnemyTime55c'])o[field]??=0;}
const clearTimers=o=>{for(const field of timers)o[field]=0;};
const playerMode=async(o,p)=>integer(o.nativeField89c,'PC flag')!==0||await p.possessed(o)!==0;
const elapsed=(now,o,day,time,p)=>{const out=p.subtract(now,{day:u32(o[day],day),time:u32(o[time],time)});if(out.status!==0)throw new Error('Native rest elapsed output is uninitialized after failed subtraction');return u32(out.time??out.milliseconds,'elapsed time');};
const div=(n,d)=>{if(d===0)throw new Error('Native rest unsigned division by zero');return Math.trunc((n>>>0)/(d>>>0))>>>0;};
const short=v=>(integer(v,'hit points')<<16)>>16;

// CNWSCreature::Rest14039f360..740. It clears existing actions BEFORE
// rejecting excitement, and queues action42; no restoration occurs here.
export async function requestRest(o,associate,seen,p){
 associate=integer(associate,'associate flag');seen=integer(seen,'enemy visibility flag');
 if(await p.dead(o)!==0||await p.dying(o)!==0)return;
 let query=o;if(associate!==0&&o.masterId!==OBJECT_INVALID)query=p.creature(o.masterId)??o;
 if((o.associateType&65535)===3&&associate===0){await p.feedback(o,153);return;}
 const player=Number(await playerMode(o,p));
 if(player){if(p.area(o)&&integer(p.noRest(p.area(o)),'area no-rest')!==0){await p.feedback(o,54);return;}}
 if(await p.nearestEnemy(query,p.enemyRadius(),OBJECT_INVALID,seen,0)!==OBJECT_INVALID){await p.feedback(o,186);return;}
 await p.clearActions(o);
 if(player&&u32(o.excitedDuration,'excited duration')>0){await p.feedback(o,17);return;}
 clearTimers(o);
 for(const bit of [1,2,8])if((o.activities&bit)!==0&&(o.lockedActivities&bit)===0)await p.activity(o,bit,0);
 await p.activity(o,16,1);await p.actionManager(o,8);
 if(player){await p.feedback(o,18);await p.restEvent(o,1);}
 else await p.runRestScript(o,9);
 await p.queue(o,42,65535,[{type:1,value:player},{type:1,value:0}],false);
}

// CancelRest140386940..6b0f: no timer zeroing here. Callers that require
// that mutation perform it before cancellation. Associate type1 only.
export async function cancelRest(o,reason,p){
 await p.animation(o,0);await p.feedback(o,integer(reason,'cancel feedback')&65535);await p.activity(o,16,0);
 if(await playerMode(o,p)){await p.restEvent(o,3);if(await playerMode(o,p))await p.stopTiming(o);}
 const ids=p.associates(o);if(ids)for(let i=0;i<ids.length;i++){const a=p.creature(ids[i]);if(a&&(a.associateType&65535)===1){await p.deleteCurrent(a);await p.animation(a,0);}}
}

// Complete AIActionRest1403ca890..b8f9, with profiling/CRT/GUI allocation
// outside the semantic boundary. Preserve progressive HP/spell recovery,
// repeated active lookups, effect callback order and raw parameter started.
export async function executeRest(o,node,p){
 if((o.associateType&65535)===3&&p.client(o.id)){await p.feedback(o,177);return 3;}
 const player=integer(node.parameterData[0],'action player flag'),started=integer(node.parameterData[1],'action started'),now=p.time(o.id);
 if(await p.dead(o)!==0||await p.dying(o)!==0){await p.activity(o,16,0);return 3;}
 if(player){if(p.area(o)&&integer(p.noRest(p.area(o)),'area no-rest')!==0){await p.activity(o,16,0);await p.feedback(o,54);return 3;}}
 if(started===0){
  o.nativeRestStartDayAd8=now.day;o.nativeRestStartTimeAdc=now.time;node.parameterData[1]=0x01010101;
  await p.clearEffectsOnOthers(o);
  for(let i=0;i<p.effects(o).length;i++){const effect=p.effects(o)[i];if((effect.type&65535)>35)break;if((effect.type&65535)===35){await p.poison(o,effect,now);await p.removeLater(o,p.effects(o)[i]);}}
  if(integer(o.nativeField89c,'PC flag')!==0||(o.associateType&65535)===3&&p.client(o.id))await p.startTiming(o,p.duration(o),6);
  const ids=p.associates(o);if(ids)for(let i=0;i<ids.length;i++){const a=p.creature(ids[i]);if(!a)continue;const type=a.associateType&65535;
   if(type>=1&&type<=3)await p.rest(a,1,0);
   else if(type>=5&&type<=6&&p.creature(a.masterId)){a.lastAssociateCommand=-12;await p.removeDomination(a);}
  }
 }
 await p.activityManager(o,2);
 if(player||o.masterId!==OBJECT_INVALID&&((o.associateType&65535)-1&65535)<=2){
  if(u32(o.excitedDuration,'excited duration')>0){
   if((o.activities&16)!==0){clearTimers(o);await p.cancel(o,214);await p.feedback(o,20);}
   else{await p.feedback(o,17);await p.animation(o,0);clearTimers(o);await p.stopTiming(o);await p.activity(o,16,0);}
   return 3;
  }
  const type=o.associateType&65535;await p.animation(o,type===2||type===3?0:47);
  if(elapsed(now,o,'nativeRestEnemyDay558','nativeRestEnemyTime55c',p)>=500){
   if(await p.nearestEnemy(o,p.enemyRadius(),OBJECT_INVALID,1,0)!==OBJECT_INVALID){clearTimers(o);await p.cancel(o,186);return 3;}
   o.nativeRestEnemyDay558=now.day;o.nativeRestEnemyTime55c=now.time;
  }
  const time=elapsed(now,o,'nativeRestStartDayAd8','nativeRestStartTimeAdc',p),duration=u32(p.duration(o),'duration');
  const missing=(short(p.maxHP(o,1))-short(p.currentHP(o,1)))|0;
  if(short(p.maxHP(o,1))>short(p.currentHP(o,1))){
   let original=u32(o.nativeRestMissingHP858,'initial missing HP');
   if(original===0){original=(short(p.maxHP(o,1))-short(p.currentHP(o,1)))>>>0;o.nativeRestMissingHP858=original;}
   const interval=Math.max(u32(o.nativeRestHealInterval854,'heal interval')||div(duration,original),1);o.nativeRestHealInterval854=interval;
   const remaining=(original-div(time,interval))>>>0;
   if(remaining<(missing>>>0))await p.writeHP(o,(short(p.currentHP(o,1))-remaining+missing)|0);
  }
  const highest=u32(p.highestSpellLevel(o),'highest spell level'),count=Math.max(1,highest),third=Math.trunc(duration/3)>>>0;
  if(time>=third){
   let interval=u32(o.nativeRestSpellInterval85c,'spell interval');if(interval===0){interval=div((third*2)>>>0,count);o.nativeRestSpellInterval85c=interval;}
   const amount=div((time-third)>>>0,interval),limit=amount>count?(count-1)>>>0:amount;
   for(let n=u32(o.nativeRestSpellCursor860,'spell cursor');n<limit;n++)await p.readyLevel(o,n&255);
   o.nativeRestSpellCursor860=limit;
  }
  if(time<duration)return 1;
  await p.animation(o,0);
 }
 await p.removeBadEffects(o);
 for(let i=0;i<p.effects(o).length;i++){const effect=p.effects(o)[i];if((effect.type&65535)>5)break;if((effect.type&65535)===5)await p.disease(o,effect,now);}
 await p.writeHP(o,short(p.maxHP(o,1)));
 for(let level=0;level<10;level++)await p.readyLevel(o,level);
 await p.restoreItems(o);await p.resetFeats(o);await p.resetAbilities(o);clearTimers(o);
 if(player){await p.feedback(o,19);await p.restEvent(o,2);}
 await p.stopTiming(o);await p.activity(o,16,0);await p.encumbrance(o,1);return 2;
}

// Input6/13, branch140454244: shared controlled-object/8ac admission.
export async function receiveRestInput(client,p){
 const object=p.clientObject(client);let actor=object?p.asCreature(object):null;if(actor&&integer(actor.nativeField8ac,'input veto')!==0)actor=null;
 if(p.overflow()!==0||!actor)return 0;
 if(integer(actor.commandable,'commandability')===0){await p.feedback(actor,213);return 0;}
 if(await p.activityState(actor,16)!==0)return 0;await p.rest(actor,0,0);return 0;
}
// Module script event35 at14047cfa7..cfc3: source ID and BYTE event type
// survive deleted creatures and absent scripts. RunEventScript owns emptiness.
export async function receiveModuleRestEvent(module,caller,payload,p){
 module.nativeLastPCRested380=integer(caller,'rest event caller')>>>0;module.nativeLastRestEvent384=integer(payload.integers?.[0]??0,'rest event integer')&255;
 await p.runEventScript(module,12,0);
}
