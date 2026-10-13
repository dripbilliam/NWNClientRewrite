import { OBJECT_INVALID } from './game_object_array.js';
import { subtractWorldTimes } from './reputation.js';

const i=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native heartbeat ${name} is unavailable`);return value|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native heartbeat provider ${name} is unavailable`);return p[name];};
function elapsed(now,day,time,p,initialized=false){
  const result=subtractWorldTimes(now,{day:i(day,'previous day')>>>0,time:i(time,'previous time')>>>0},p.dayLength);
  if(result.status===0)return result.milliseconds;
  // The main heartbeat/perception pairs initialize both outputs to zero.
  // Cleanup owners instead leave them uninitialized on subtraction failure.
  if(initialized)return 0;
  throw new Error('Native heartbeat time subtraction left uninitialized output');
}

// SpawnInHeartbeatPerception1403a4410..1403a4bbc. Active timer is captured
// once, BEFORE OnSpawn. Perception follows heartbeat and reputation cleanup.
// AI-level list scheduling is a separate caller, not a fixed 4-second loop.
export async function spawnHeartbeatPerception(actor,frame,p){
  frame=i(frame,'frame flag');const now=await required(p,'activeTime')(actor);
  const heartbeatElapsed=elapsed(now,actor.nativeHeartbeatDay54c,actor.nativeHeartbeatTime550,p,true);
  if(i(actor.nativeSpawnState548,'spawn state')===0){
    await required(p,'runEvent')(actor,8);
    if((i(actor.nativeField948,'spawn target')>>>0)===OBJECT_INVALID)actor.nativeSpawnState548=1;
  }
  if(frame===1&&heartbeatElapsed>=(i(actor.nativeHeartbeatInterval554,'heartbeat interval')>>>0)||actor.nativeSpawnState548===0){
    actor.nativeHeartbeatCounter584=(i(actor.nativeHeartbeatCounter584,'heartbeat counter')+1)|0;
    if(i(actor.nativeAILevel7c,'AI level')!==0||(actor.nativeHeartbeatCounter584>>>0)>=(actor.nativeHeartbeatInterval554>>>6)||actor.nativeSpawnState548===0){
      actor.nativeHeartbeatCounter584=0;
      if((actor.nativeSpawnState548===0||i(actor.nativeHeartbeatTime550,'heartbeat time')!==0)&&
         i(await required(p,'dead')(actor),'dead result')===0&&i(await required(p,'dying')(actor),'dying result')===0){
        let run=true;
        if((i(actor.masterId,'master ID')>>>0)!==OBJECT_INVALID){
          if((i(actor.nativeField8d6,'control byte')&255)===2||(i(actor.nativeField771,'control script byte')&255)!==0)run=false;
          if(i(await required(p,'possessed')(actor),'possessed result')!==0&&
             i(await required(p,'rulesetInt')('ALL_ASSOCIATES_RUN_SCRIPTS',0),'associate scripts')===0)run=false;
        }
        let status=i(actor.nativeField771,'control script byte')&255;
        if(status<=9&&(0x25e&(1<<status))||status===8)actor.nativeFieldEc=0;
        if(run||(i(actor.associateType,'associate type')&65535)===5){
          await required(p,'runEvent')(actor,0);status=i(actor.nativeField771,'control script byte')&255;
        }
        if(status!==0&&(status<=4||status===6||status===8||status===9)){
          await required(p,'controlScript')(actor,status);actor.nativeFieldEc=0;
        }
        if((i(actor.associateType,'associate type')&65535)===6){
          await required(p,'controlScript')(actor,7);actor.nativeFieldEc=0;
        }
        await required(p,'cleanInvitations')(actor,0);
      }
      if(i(actor.nativeField58c,'associate cleanup flag')!==1){
        const master=await required(p,'creature')(i(actor.masterId,'master ID')>>>0);
        if(!master){
          const type=i(actor.associateType,'associate type')&65535;
          if(type>=2&&type<=4){
            await required(p,'clearActions')(actor);
            await required(p,'enqueue')(11,actor.id,actor.id,0,null);
          }else if(type===5||type===6)await required(p,'removeDomination')(actor);
          else{
            let clear=type===7||type===8;
            if(type===1){
              if(i(actor.nativeOrphanState918,'orphan state')===0){actor.nativeOrphanState918=1;actor.nativeOrphanDay91c=now.day>>>0;actor.nativeOrphanTime920=now.time>>>0;}
              else clear=elapsed(now,actor.nativeOrphanDay91c,actor.nativeOrphanTime920,p)>=300000;
            }
            if(clear){
              await required(p,'setAssociateType')(actor,0);
              await required(p,'setMasterId')(actor,OBJECT_INVALID);
              actor.nativeOrphanState918=actor.nativeOrphanDay91c=actor.nativeOrphanTime920=0;
            }
          }
        }else if(i(actor.nativeOrphanState918,'orphan state')===1)actor.nativeOrphanState918=actor.nativeOrphanDay91c=actor.nativeOrphanTime920=0;
      }
      actor.nativeHeartbeatDay54c=now.day>>>0;actor.nativeHeartbeatTime550=now.time>>>0;
      actor.nativeHeartbeatInterval554=i(await required(p,'random')(),'heartbeat random')%1200+6000;
    }
    let count=i(actor.nativeReputationCounter590,'reputation counter')&255;
    if(count===30){await required(p,'cleanReputations')(actor);count=0;}
    actor.nativeReputationCounter590=(count+1)&255;
  }
  const perceptionElapsed=elapsed(now,actor.nativePerceptionDay578,actor.nativePerceptionTime57c,p,true);
  let due=actor.nativeSpawnState548===0;
  if(!due){
    const controlled=i(await required(p,'pc')(actor),'PC result')!==0||i(await required(p,'possessed')(actor),'possessed result')!==0;
    due=controlled&&frame===1&&perceptionElapsed>=200;
    if(!due)due=i(await required(p,'pc')(actor),'PC result')===0&&i(await required(p,'possessed')(actor),'possessed result')===0&&frame===1&&perceptionElapsed>=4000;
  }
  if(due){
    actor.nativePerceptionCounter580=(i(actor.nativePerceptionCounter580,'perception counter')+1)|0;
    if(i(actor.nativeAILevel7c,'AI level')===0&&actor.nativePerceptionCounter580<150&&actor.nativeSpawnState548!==0)return;
    actor.nativePerceptionCounter580=i(await required(p,'random')(),'perception random')%50;
    if(i(actor.nativePerceptionTime57c,'perception time')!==0||actor.nativeSpawnState548===0){
      await required(p,'updateVisibility')(actor);
      if(await required(p,'client')(actor.id)){
        const area=await required(p,'area')(actor);
        if(area){
          const tile=await required(p,'tile')(await required(p,'area')(actor),actor.position);
          if(tile&&((i(actor.nativeAutoMapTileX6e4,'automap tile X')&255)!==tile.x||
             (i(actor.nativeAutoMapTileY6e5,'automap tile Y')&255)!==tile.y||
             (actor.areaId>>>0)!==(i(actor.nativeAutoMapArea6e8,'automap area')>>>0))){
            await required(p,'updateAutoMap')(actor,actor.id);
            actor.nativeAutoMapTileX6e4=tile.x&255;actor.nativeAutoMapTileY6e5=tile.y&255;actor.nativeAutoMapArea6e8=actor.areaId>>>0;
          }
        }
      }
    }
    actor.nativePerceptionDay578=now.day>>>0;actor.nativePerceptionTime57c=now.time>>>0;
    if(await required(p,'area')(actor)&&i((await required(p,'area')(actor)).nativePlayerCount150,'area player count')===0&&i(actor.nativeAILevel7c,'AI level')!==0)
      await required(p,'setAILevel')(actor,0);
  }
  if(actor.nativeSpawnState548===0)actor.nativeSpawnState548=1;
}

// CleanOutPersonalReputationList1403d3510; reverse deletion retains capacity.
export async function cleanPersonalReputations(actor,p){
  const list=actor.personalReputationList;if(list===null)return;
  if(!Array.isArray(list))throw new Error('Native personal reputation list is unavailable');
  for(let index=list.length-1;index>=0;index--){
    const entry=list[index];
    if(!await required(p,'creature')(entry.objectId>>>0)){list.splice(index,1);continue;}
    if(i(entry.decays,'decay flag')!==0){
      const now=await required(p,'worldTime')();
      if(Math.fround(elapsed(now,entry.day,entry.time,p))>Math.fround(Math.fround(i(entry.duration,'reputation duration'))*1000))list.splice(index,1);
    }
  }
}

// SetInvitedToParty1403a32e0 / CleanInvitationLists1403d31c0. Two nullable
// arrays of 12-byte records; the force flag affects only the outgoing list.
export async function setInvitedToParty(actor,value,p){
  actor.nativeInvited7dc=i(value,'invitation flag');const now=await required(p,'worldTime')();
  actor.nativeInvitationDay7e0=now.day>>>0;actor.nativeInvitationTime7e4=now.time>>>0;
}
export async function cleanInvitationLists(actor,force,p){
  const now=await required(p,'worldTime')();force=i(force,'invitation force');
  const outgoing=actor.nativeInvitations7e8,incoming=actor.nativeInvitations7f0;
  if(outgoing!==null){
    if(!Array.isArray(outgoing))throw new Error('Native outgoing invitations are unavailable');
    for(let index=outgoing.length-1;index>=0;index--){const entry=outgoing[index];
      if(force!==0||elapsed(now,entry.day,entry.time,p)>30000){
        const target=await required(p,'creature')(entry.objectId>>>0);
        if(target)await setInvitedToParty(target,0,p);
        outgoing.splice(index,1);
        if(target)await required(p,'feedback')(target,43,{objectIds:[actor.id>>>0]});
      }
    }
  }
  if(incoming!==null){
    if(!Array.isArray(incoming))throw new Error('Native incoming invitations are unavailable');
    for(let index=incoming.length-1;index>=0;index--){const entry=incoming[index];if(elapsed(now,entry.day,entry.time,p)>60000)incoming.splice(index,1);}
  }
  if(elapsed(now,actor.nativeInvitationDay7e0,actor.nativeInvitationTime7e4,p)>30000)await setInvitedToParty(actor,0,p);
}
