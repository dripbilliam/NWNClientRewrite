import { OBJECT_INVALID } from './game_object_array.js';
import { intEntry } from './combat_stats.js';

const i=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native ${name} is unavailable`);return value|0;};
const f=Math.fround;
const cvtt=value=>Number.isFinite(value)&&value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;
// ClearPersonalReputation1403d3680. NPC->PC redirects to the PC's list;
// remove every matching record in reverse, preserving allocation capacity.
export function clearPersonalReputation(actor,targetId,p){
  targetId=i(targetId,'personal reputation target')>>>0;let target=p.creature(targetId);
  if(target&&i(target.nativeStatsIsPCb0,'target stats PC')===1&&i(actor.nativeStatsIsPCb0,'owner stats PC')===0){targetId=actor.id>>>0;actor=target;}
  if(!Array.isArray(actor.personalReputationList))throw new Error('Native personal reputation list is unavailable');
  for(let index=actor.personalReputationList.length-1;index>=0;index--)if(actor.personalReputationList[index].objectId===targetId)actor.personalReputationList.splice(index,1);
}
// LoadReputationAdjustments 140558ad0..14055946e. Four PHYSICAL rows,
// eleven ints each, returned GetINTEntry values even when status is false.
// The null table leaves native allocations untouched; do not synthesize rows.
export function reputationAdjustments(table){
  if(!table)throw new Error('Native reputation adjustment table is unavailable');
  const columns=['PERSONALREP','FACTIONREP','WITFRIA','WITFRIB','WITFRIC','WITNEUA','WITNEUB','WITNEUC','WITENEA','WITENEB','WITENEC'];
  return Array.from({length:4},(_,row)=>columns.map(column=>intEntry(table,row,column).value));
}
// AddToPersonalReputationList 1403d0c50..1403d0daf. Append, never merge.
// Capacity is retained separately from record count. Duration is cvttss2si,
// not milliseconds. Later decay uses the existing native-traced reader.
export function addPersonalReputation(actor,targetId,amount,decays,duration,providers){
  targetId=i(targetId,'personal reputation target')>>>0;
  const target=providers.creature(targetId);
  if(!target||i(target.reputationPCFlag,'reputation PC flag')===1)return;
  if((i(target.masterId,'reputation master ID')>>>0)!==OBJECT_INVALID||target.factionId===actor.factionId)return;
  const now=providers.worldTime();
  const entry={day:i(now.day,'world day')>>>0,time:i(now.time,'world time')>>>0,objectId:targetId,
    amount:i(amount,'personal reputation amount'),decays:i(decays,'reputation decay'),duration:cvtt(f(duration))};
  if(!Array.isArray(actor.personalReputationList))throw new Error('Native personal reputation allocation is unavailable');
  let capacity=actor.personalReputationCapacity??0;
  if(!Number.isInteger(capacity)||capacity<actor.personalReputationList.length)
    throw new Error('Native personal reputation allocation capacity is unavailable');
  if(actor.personalReputationList.length===capacity)capacity=capacity===0?16:(capacity*2)|0;
  actor.personalReputationCapacity=capacity;actor.personalReputationList.push(entry);
}
// AdjustReputation 1403d0e60..1403d0f68, actual client ownership for a
// familiar. Preserve the native Get argument order independently of Set.
export async function adjustFactionReputation(actor,faction,amount,providers){
  faction=i(faction,'adjusted faction');amount=i(amount,'faction reputation adjustment');
  const table=providers.table;if(!table)throw new Error('Native faction reputation table is unavailable');
  if(!table.isNPC(faction))return;
  if(i(actor.reputationPCFlag,'reputation PC flag')===0&&
    ((i(actor.associateType,'associate type')&65535)!==3||!await providers.client(actor.id))){
    const old=table.get(actor.factionId,faction);
    if(actor.factionId!==faction)table.set(actor.factionId,faction,(old+amount)|0);
  }else if(actor.factionReputation!==null){
    if(!Array.isArray(actor.factionReputation)||!Number.isInteger(actor.factionReputation[faction-1]))throw new Error('Native PC faction reputation allocation is unavailable');
    actor.factionReputation[faction-1]=Math.max(0,Math.min(100,(actor.factionReputation[faction-1]+amount)|0));
  }
}
// AdjustTargetAndWitnessReputations 140557660..140557bb5. The scan is
// an X-window INTERSECTION, not a radius test, and its ID list is live.
// Once-per-faction changes and final friend/neutral/enemy precedence matter.
export async function adjustCombatReputations(targetId,actorId,operation,providers){
  targetId=i(targetId,'reputation target ID')>>>0;actorId=i(actorId,'reputation actor ID')>>>0;
  if(targetId===actorId)return;
  const actor=providers.creature(actorId);if(!actor||await providers.dm(actor)!==0)return;
  const target=providers.creature(targetId);if(!target||Number(target.plot)===1)return;
  const associate=i(target.associateType,'associate type')&65535,master=i(target.masterId,'master ID')>>>0;
  if(master===actorId&&((associate-5)&65535)>1)return;
  const area=providers.area(target);operation=i(operation,'reputation operation')>>>0;
  if(!area||operation>=4)return;
  const low=Math.max(f(f(target.position[0])-45),f(f(actor.position[0])-45));
  const high=Math.min(f(f(target.position[0])+45),f(f(actor.position[0])+45));
  const first=await providers.firstByX(area,low);if(first===null)return;
  const values=providers.adjustments(operation);
  if(!Array.isArray(values)||values.length!==11||!values.every(Number.isInteger))throw new Error('Native reputation adjustment row is unavailable');
  if(master!==actorId||![1,5,6].includes(associate))await providers.personal(actor,targetId,values[0],1,180);
  const targetFaction=master===actorId&&((associate-1)&0xfffa)===0&&associate!==2?
    i(target.originalFactionId,'original faction'):i(target.factionId,'target faction');
  const adjusted=new Set();let friendly=false,neutral=false,enemy=false;
  for(let index=first;index<providers.areaIds(area).length;index++){
    const id=providers.areaIds(area)[index]>>>0;if(id===actorId||id===targetId)continue;
    const witness=providers.creature(id);
    if(!witness||await providers.dead(witness)!==0||Number(witness.plot)!==0)continue;
    if(f(witness.position[0])>high)break;
    const actorFlags=providers.visibility(witness,actorId),targetFlags=providers.visibility(witness,targetId);
    if(actorFlags===null||targetFlags===null||!(actorFlags&1)||!(targetFlags&1))continue;
    const faction=i(witness.factionId,'witness faction'),rep=i(await providers.reputation(target,id),'witness reputation');
    let personal,factionAmount;
    if(faction!==targetFaction&&(witness.masterId>>>0)!==targetId&&master!==id&&rep<90){
      if(rep<=10){enemy=true;personal=values[9];factionAmount=values[10];}
      else{neutral=true;personal=values[6];factionAmount=values[7];}
    }else{friendly=true;personal=values[3];factionAmount=values[4];}
    if(faction!==targetFaction&&!adjusted.has(faction)&&await providers.npcFaction(witness)===1){
      await providers.faction(actor,faction,factionAmount);adjusted.add(faction);
    }
    if(personal!==0)await providers.personal(actor,id,personal,1,180);
    if(faction!==targetFaction)adjusted.add(faction);
  }
  if(await providers.npcFaction(target)===1){
    const adjustment=(values[1]+(friendly?values[2]:neutral?values[5]:enemy?values[8]:0))|0;
    await providers.faction(actor,targetFaction,adjustment);
  }
}
