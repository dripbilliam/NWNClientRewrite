import {usePickpocketSkill,executePickpocket} from './skill_action.js';
import {intEntry,rulesetInt} from './combat_stats.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {manageObjectActions} from './object_actions.js';
import {manageCreatureActivities,associateId} from './combat_attack_preparation.js';
import {setCombatActivity,clearCreatureActivities} from './combat_mode.js';
import {sendCombatFeedback,broadcastSkillData} from './combat_broadcast.js';
import {addMoveToPointFront} from './movement_actions.js';
import {addCreatureGold,removeCreatureGold} from './creature_gold.js';
import {acquireCreatureItem} from './item_acquisition.js';

export class SkillRuntime{
  constructor(session){this.session=session;}
  async clearActivity(o,mask,value){
    const s=this.session,c=s.combat;
    if(mask!==0&&(mask&~0x1ffc00)===0)return setCombatActivity(o,mask,value,{defensiveCasting:(o,v)=>{o.nativeField6ee=Number(v);},
      applyStance:()=>{throw new Error('Native skill defensive stance apply owner is unavailable');},removeStance:()=>{throw new Error('Native skill defensive stance remove owner is unavailable');}});
    if((o.lockedActivities&mask)===mask||!(o.activities&mask))return;
    if([1,2,8].includes(mask))return c.clearAttackActivity(o,mask,value);
    throw new Error(`Native skill noncombat activity ${mask} owner is unavailable`);
  }
  providers(){
    const s=this.session,c=s.combat,b=c.broadcastProviders(),feedback=(o,code,data)=>sendCombatFeedback(o,code,data,b),acquisition=s.itemAcquisitionProviders();
    return{object:id=>s.registry.get(id)??null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      item:id=>{const o=s.registry.get(id);if(o?.objectType!==6)return null;if(!o.nativeItemLoaded)throw new Error('Native pickpocket candidate import is unavailable');return o;},
      isDM:o=>Number(o.isDM),hostileSkill:skill=>intEntry(s.characterRules.skills,skill,'HostileSkill').value,
      canUseSkill:(o,id)=>c.canUseSkill(o,id),reaction:(o,id)=>s.aiReaction(o,id),rank:(...args)=>c.skill(...args),
      actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(b.client(o.id)),clearActions:o=>c.clearActions(o)}),
      activityManager:(o,n)=>manageCreatureActivities(o,n,(...args)=>this.clearActivity(...args)),
      clearActivities:(o,mask)=>clearCreatureActivities(o,mask,(...args)=>this.clearActivity(...args)),
      feedback,dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),inUseRange:(...args)=>c.inUseRange(...args),useRange:(...args)=>c.useRange(...args),
      moveFront:(o,group,point,area,target,run,distance)=>addMoveToPointFront(o,group,point,area,target,run,distance,0,0,0,0,0,0,0,{setLock:(...args)=>c.setLock(...args)}),
      dice:(n,d)=>s.random.dice(n,d),random:()=>s.random.next(),rule:(name,fallback)=>rulesetInt(s.characterRules,name,fallback),
      reputations:(...args)=>c.adjustReputations(...args),associate:(...args)=>associateId(...args,id=>s.registry.get(id)),client:b.client,
      unpossess:()=>{throw new Error('Native pickpocket familiar unpossess owner is unavailable');},
      repository:o=>o.nativeRepository,baseInfo:i=>s.items.baseInfo(i),acquire:(...args)=>acquireCreatureItem(...args,acquisition),
      broadcastSkill:(o,data)=>broadcastSkillData(o,data,b),addGold:(...args)=>addCreatureGold(...args,{feedback}),removeGold:(...args)=>removeCreatureGold(...args,{feedback}),
      event:(source,target,type,objectIds,integers)=>c.enqueueEvent(10,source,target,0,{type,objectIds,integers})};
  }
  async use(actor,skill,target,mode,item){
    if(actor?.objectType!==5||this.session.registry.get(actor.areaId)?.objectType!==4)return;
    return usePickpocketSkill(actor,skill,mode,target,[0,0,0],actor.areaId,item,0,this.providers());
  }
  execute(actor,node){return executePickpocket(actor,node,this.providers());}
}
