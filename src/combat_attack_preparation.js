import { OBJECT_INVALID } from './game_object_array.js';
import { setRoundPaused,setPauseTimer } from './combat_timing.js';

// GetAssociateId 1403d4d70. Ordered canonical IDs; nth counts only matching
// live creatures. The native -1 sentinel never selects an associate.
export function associateId(actor,type,nth,creature){
  if(![type,nth].every(Number.isInteger))throw new Error('Native associate query is unavailable');
  if(nth===-1||actor.associateIds===null)return OBJECT_INVALID;
  if(!Array.isArray(actor.associateIds))throw new Error('Native associate list is unavailable');
  let count=1;for(let index=0;index<actor.associateIds.length;index++){
    const id=actor.associateIds[index]>>>0,target=creature(id);
    if(target&&(target.associateType&65535)===(type&65535)){if(nth===count)return id;count++;}
  }
  return OBJECT_INVALID;
}
// ActivityManager 14037cc30..14037cddf. Re-read masks after each activity
// side effect; a locked bit is skipped. Attack request4 preserves combat modes.
export async function manageCreatureActivities(actor,request,setActivity){
  if(![actor.activities,actor.lockedActivities,request].every(Number.isInteger))throw new Error('Native activity manager state is unavailable');
  if(typeof setActivity!=='function')throw new Error('Native activity mutation is unavailable');
  if(request!==4){await setActivity(actor,0x1ffc00,0);if(request!==1)return;}
  for(const bit of request===4?[1,2,8]:[1,2,8,32,64,128,256,512]){
    if((actor.activities&bit)!==0&&(actor.lockedActivities&bit)===0)await setActivity(actor,bit,0);
  }
}
// ResolveAttack 1403e3c60..1403e3fa5, preparation before ranged/melee
// dispatch. Live status removal and familiar/associate commands are explicit
// operations, not silent record deletions or inferred successful commands.
export async function prepareAndResolveAttack(actor,targetId,count,duration,p){
  if(![targetId,count,duration].every(Number.isInteger))throw new Error('Native attack dispatch arguments are unavailable');
  targetId>>>=0;const object=p.object(targetId);
  if(!object||![5,9,10].includes(object.objectType)){
    setRoundPaused(actor.combatRound,0,OBJECT_INVALID);setPauseTimer(actor.combatRound,0,0);
    await p.setAnimation(actor,1);return;
  }
  actor.nativeAttackTarget724=targetId;
  const target=object.objectType===5?object:null;
  if(target){
    await p.reputations(targetId,actor.id,0);
    if(await p.associateId(target,3,1)!==OBJECT_INVALID){
      const familiar=await p.associateId(target,3,1);
      if(await p.client(familiar))await p.unpossess(target);
    }
    const ids=target.associateIds;
    if(ids!==null){
      if(!Array.isArray(ids))throw new Error('Native defender associate list is unavailable');
      for(let index=0;index<ids.length;index++){
        const associate=p.creature(ids[index]>>>0);if(associate)await p.associateCommand(associate,-11);
      }
    }
    if(((target.associateType-5)&65535)<2&&target.factionId===actor.factionId){
      const effect=(target.effects??[]).find(e=>e?.type===8&&(e.subtype&7)===1&&(e.integers?.[0]??0)===7&&e.creatorId===target.masterId);
      if(effect)await p.removeEffect(target,effect.id);
    }
    if((target.creatureState&255)===1){
      const effect=(target.effects??[]).find(e=>{
        if(e?.type!==8||(e.subtype&7)!==1||(e.integers?.[0]??0)!==1)return false;
        const creator=p.creature(e.creatorId);return creator&&creator.factionId===actor.factionId;
      });
      if(effect)await p.removeEffect(target,effect.id);
    }
  }
  await p.activityManager(actor,4);
  if(await p.ranged(actor)===1)await p.rangedAttack(actor,object,count|0,duration|0);
  else await p.meleeAttack(actor,object,count|0,duration|0);
}
