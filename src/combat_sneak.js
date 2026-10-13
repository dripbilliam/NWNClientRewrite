import { OBJECT_INVALID } from './game_object_array.js';
import { getAttackData } from './combat_attack_data.js';
import { rulesetInt, rulesetFloat } from './combat_stats.js';
import { nativeDistanceSquared } from './nearest_objects.js';

const range=(a,b)=>Array.from({length:b-a+1},(_,i)=>a+i);
const featLists={sneak:[221,...range(345,353),...range(1032,1041),460,461,462,...range(1007,1018),...range(834,843)],
  death:[455,456,457,458,459,1004,1005,1006,...range(1019,1030)]};
// Native ResolveSneakAttack's final epic ladder is 834..843, while damage
// dice count uses 842..851. Preserve this build discrepancy, not feat names.
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native sneak attack ${name} is unavailable`);return value|0;};

// GetFlanked 0x1403e3850..1403e3902: a target-state query, no geometric
// rear arc. Spell references to the attacker, its area, or defender veto it.
export function getFlanked(actor,target,hasFeat) {
  if(!target)return 0;
  if(hasFeat(target,950)===1)return 0;
  const id=integer(actor.id,'actor ID')>>>0,area=integer(actor.areaId,'actor area ID')>>>0,targetId=integer(target.id,'target ID')>>>0;
  const attack=integer(target.nativeAttackTarget724,'active attack target')>>>0,queued=integer(target.attackActionTargetId,'queued attack target')>>>0;
  const spell=integer(target.spellActionTargetId,'spell target')>>>0,other=integer(target.nativeTarget740,'target +740')>>>0;
  if([attack,queued,spell,other].includes(id)||[area,targetId].includes(spell)||[area,targetId].includes(other))return 0;
  return Number([attack,queued,spell,other].some(value=>value!==OBJECT_INVALID));
}
// ResolveSneakAttack 0x1403ebe00 / ResolveDeathAttack 0x1403e5040 share
// eligibility, but have distinct feat gates and distance setup conditions.
export async function resolvePrecisionAttack(kind,actor,target,rules,p) {
  if(!target)return;
  if(!featLists[kind])throw new Error('Unknown native precision attack kind');
  for(const name of ['hasFeat','visibility','flatFooted','flanked','classes','effectImmunity','message'])
    if(typeof p[name]!=='function')throw new Error(`Native precision attack provider ${name} is unavailable`);
  const round=actor.combatRound,index=round.currentAttack&255,data=getAttackData(round,index,p.warning),ranged=data.ranged;
  if(((data.attackType-867)&65535)<2)return;
  let has=false;for(const feat of featLists[kind])if(await p.hasFeat(actor,feat)!==0){has=true;break;}
  if(!has)return;
  let distance=0;
  if(kind==='sneak'?ranged!==0:ranged===1){
    if(![actor,target].every(o=>o.position?.length===3&&o.position.every(Number.isFinite)))throw new Error('Native precision attack position is unavailable');
    distance=nativeDistanceSquared(actor.position,target.position);
  }
  const inRange=()=>{const length=rulesetFloat(rules,'MAX_RANGED_SNEAK_ATTACK_DISTANCE',10);return distance<=Math.fround(length*length);};
  const flags=await p.visibility(target,actor.id);
  if(flags!==null&&!Number.isInteger(flags))throw new Error('Native precision attack visibility flags are unavailable');
  let eligible=false;
  if(flags===null||(flags&1)===0){
    if(ranged===0||ranged===1&&inRange())eligible=true;
    else if(await p.flatFooted(target)===1)eligible=ranged===0||ranged===1&&inRange();
  }else if(await p.flatFooted(target)===1)eligible=ranged===0||ranged===1&&inRange();
  let allowFlank=await p.hasFeat(target,251)===0;
  if(!allowFlank){
    const levels=async object=>{
      const list=await p.classes(object);if(!Array.isArray(list))throw new Error('Native precision attack class records are unavailable');
      let sum=0;for(const c of list.slice(0,list.length&255))if([8,0,30,27].includes(integer(c.Class,'class ID')&255))sum=(sum+(integer(c.ClassLevel,'class level')&255))|0;
      return sum;
    };
    const attacking=await levels(actor),defending=await levels(target);
    allowFlank=((rulesetInt(rules,'FLANK_LEVEL_RANGE',4)+defending)|0)<=attacking;
  }
  if(allowFlank&&await p.flanked(actor,target)===1&&(ranged===0||ranged===1&&inRange()))eligible=true;
  if(!eligible)return;
  if(await p.effectImmunity(target,30,actor,1)===0&&await p.effectImmunity(target,31,actor,1)===0)
    getAttackData(actor.combatRound,index,p.warning)[kind==='sneak'?'sneakAttack':'deathAttack']=1;
  else getAttackData(actor.combatRound,index,p.warning).lists[3].push(await p.message(0,{objects:[target.id],integers:[134]}));
}
