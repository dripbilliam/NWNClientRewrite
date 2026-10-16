import {requestRest,executeRest,cancelRest,receiveRestInput,receiveModuleRestEvent} from './rest.js';
import {removeRestEffects,clearCasterEffects,restoreCreatureItems,removeDominationEffect} from './rest_resources.js';
import {restoreActiveProperties} from './item_property_pool.js';
import {readySpellLevel,highestKnownSpellLevel,resetSpellLikeAbilities} from './spell_book.js';
import {spellGainWithBonus} from './spell_book.js';
import {creatureLevel} from './negative_level_effect.js';
import {intEntry,rulesetFloat} from './combat_stats.js';
import {subtractWorldTimes} from './world_timer.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,deleteCurrentObjectAction,manageObjectActions} from './object_actions.js';
import {manageCreatureActivities} from './combat_attack_preparation.js';
import {sendCombatFeedback} from './combat_broadcast.js';
const requiredInt=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native rest ${n} is unavailable`);return v|0;};

export class RestRuntime{
 constructor(session){this.session=session;}
 resourceProviders(){const s=this.session;return{object:id=>s.registry.get(id)??null,asWorld:o=>o.objectType>=5&&o.objectType<=14?o:null,
  asAreaEffect:o=>o.objectType===11?o:null,areaEffectCreator:o=>requiredInt(o.nativeAreaEffectCreator330,'area effect creator')>>>0,
  effects:o=>o.effects,remove:(o,id)=>s.effects.remove(o.id,id),destroyLater:(o,id)=>s.combat.enqueueEvent(11,o.id,id,0,null)};}
 ready(o,level){return readySpellLevel(o,level,this.session.characterRules,{spellGainWithBonus:(actor,index,l)=>spellGainWithBonus(actor,index,l,this.session.characterRules,this.session.spellBook.providers(actor))});}
 removeBad(o){return removeRestEffects(o,this.resourceProviders());}
 clearOthers(o){return clearCasterEffects(o,this.resourceProviders());}
 removeDomination(o){return removeDominationEffect(o,this.resourceProviders());}
 restoreItems(o){const s=this.session;return restoreCreatureItems(o,{equipped:(o,slot)=>s.equipmentSlot(o,slot),repository:o=>o.nativeRepository,
  first:repo=>repo.head,next:(_repo,node)=>node.next,at:(_repo,node)=>{const item=s.registry.get(node.id);return item?.objectType===6?item:null;},
  baseInfo:i=>s.items.baseInfo(i),container:base=>requiredInt(base.container,'base item container'),restore:restoreActiveProperties,update:(...args)=>s.items.activeChanged(...args)});}
 duration(o){const s=this.session,table=s.characterRules.restduration;if(!table)throw new Error('Native RestDuration.2da is unavailable');
  const level=creatureLevel(o,0,message=>s.combat.warning(o,message)),entry=intEntry(table,level,'DURATION');if(!entry.found)throw new Error('Native rest duration output is uninitialized');return entry.value>>>0;}
 timing(o,start,duration=0,type=0){const s=this.session,b=s.combat.broadcastProviders();
  if(o.nativeField89c===0&&!((o.associateType&65535)===3&&b.client(o.id)))return;
  const client=b.client(o.id);if(!client)return;
  // Local client projection of the mapped Start/StopGuiTimingBar delivery;
  // it is deliberately not a native server creature field or packet claim.
  client.guiTiming={active:start,duration:duration>>>0,type:type&255,started:s.worldTimer.time()};
 }
 event(o,state){const s=this.session;if(!s.module)throw new Error('Native rest module is unavailable');
  // Original AddEventAbsoluteTime(0,0) is immediately due. Local scheduler
  // represents this delivery at its current clock; native packet/calendar
  // timestamp encoding remains a separate adapter boundary.
  return s.combat.enqueueEvent(10,o.id,s.module.id,0,{type:35,integers:[state],objectIds:[]});}
 receiveEvent(caller,payload){const s=this.session;return receiveModuleRestEvent(s.module,caller,payload,{runEventScript:async(m,index)=>{
  const name=s.ifo?.Mod_OnPlrRest??'';if(name)await s.runScript(name,m.id,{scriptEventContext:(m.nativeScriptObjectType34&255)*1000+index});}});}
 providers(){const s=this.session,c=s.combat,b=c.broadcastProviders(),effects=s.effects.afflictionProviders();
  return{dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),possessed:o=>Number((o.associateType&65535)===3&&Boolean(b.client(o.id))),
   creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},noRest:a=>requiredInt(a.nativeMessageFields?.[0x100],'area no-rest flag'),
   enemyRadius:()=>rulesetFloat(s.characterRules,'REST_ENEMY_CHECK_DISTANCE',30),nearestEnemy:(...args)=>c.targetProviders().nearestEnemy(...args),
   client:b.client,time:()=>s.worldTimer.time(),subtract:(a,b)=>subtractWorldTimes(a,b,s.worldTimer.dayLength),
   feedback:(o,code)=>sendCombatFeedback(o,code,null,b),clearActions:o=>c.clearActions(o),
   activity:(o,mask,value)=>this.activity(o,mask,value),actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(b.client(o.id)),clearActions:o=>c.clearActions(o)}),
   activityManager:(o,n)=>manageCreatureActivities(o,n,(...args)=>s.skills.clearActivity(...args)),
   queue:(o,...args)=>addObjectAction(o.objectActionState,...args),restEvent:(...args)=>this.event(...args),
   runRestScript:async(o,index)=>{if(o.scripts?.rest)await s.runScript(o.scripts.rest,o.id,{scriptEventContext:(o.objectType&255)*1000+index});},
   animation:(o,n)=>c.setAnimation(o,n),effects:o=>o.effects,clearEffectsOnOthers:o=>this.clearOthers(o),
   poison:(o,e)=>effects.poisonPayload(o,e),disease:(o,e,now)=>effects.diseasePayload(o,e,now),removeLater:(o,e)=>c.enqueueEvent(14,o.id,o.id,0,e),
   duration:o=>this.duration(o),startTiming:(o,n,t)=>this.timing(o,1,n,t),stopTiming:o=>this.timing(o,0),
   associates:o=>o.associateIds,rest:(...args)=>this.request(...args),removeDomination:o=>this.removeDomination(o),
   deleteCurrent:o=>deleteCurrentObjectAction(o,{clearAction:(...args)=>c.clearAction(...args),deleteSituation:s=>this.session.deleteSituation(s)}),
   cancel:(...args)=>this.cancel(...args),maxHP:(o,n)=>s.hitPoints(o.id,true,n),currentHP:(o,n)=>n===1?o.stats.currentHP:s.hitPoints(o.id,false),
   writeHP:(o,n)=>{o.stats.currentHP=n;s.damage.synchronize(o);},highestSpellLevel:highestKnownSpellLevel,readyLevel:(...args)=>this.ready(...args),
   removeBadEffects:o=>this.removeBad(o),restoreItems:o=>this.restoreItems(o),resetFeats:o=>o.featUsePool.reset(),resetAbilities:resetSpellLikeAbilities,encumbrance:(...args)=>c.encumbrance(...args)};
 }
 activity(o,mask,value){if(mask!==16)return this.session.skills.clearActivity(o,mask,value);
  if((o.lockedActivities&16)===16)return;o.activities=value===1?(o.activities|16)>>>0:(o.activities&~16)>>>0;
 }
 request(o,associate=0,seen=0){return requestRest(o,associate,seen,this.providers());}
 cancel(o,reason){return cancelRest(o,reason,this.providers());}
 execute(o,node){return executeRest(o,node,this.providers());}
 async clear(o,node,head){if(node.nativeField9c===0)return 0;await this.cancel(o,20);
  if(o.lockOrientationId!==OBJECT_INVALID)this.session.combat.setLock(o,OBJECT_INVALID);
  if(Number(head)===1)o.objectActionState.startDay=o.objectActionState.startTime=0;return 1;
 }
 input(){const s=this.session;return receiveRestInput(null,{clientObject:()=>s.player,asCreature:o=>o.objectType===5?o:null,overflow:()=>0,
  feedback:(o,code)=>sendCombatFeedback(o,code,null,s.combat.broadcastProviders()),activityState:(o,mask)=>Number((o.activities&mask)!==0),rest:(...args)=>this.request(...args)});}
 async force(id){const s=this.session,o=s.registry.get(id);if(o?.objectType!==5||s.isDead(o))return;
  const p=this.providers();await p.clearActions(o);await p.clearEffectsOnOthers(o);await p.removeBadEffects(o);
  for(let level=0;level<10;level++)await p.readyLevel(o,level);await p.writeHP(o,(p.maxHP(o,1)<<16)>>16);
  await p.restoreItems(o);await p.resetFeats(o);await p.resetAbilities(o);await p.encumbrance(o,1);
 }
}
