import {getAttackData,totalAttackDamage} from './combat_attack_data.js';
import {attackResultDoesDamage} from './combat_strike.js';
import {rulesetInt,rulesetFloat} from './combat_stats.js';
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native ranged special provider ${n} is unavailable`);return p[n];};
// ResolveRangedSpecialAttack1403eb510..1403ebaab. Only called-shot
// IDs65000/65001 append extra effects; all others perform normal resolution.
export async function resolveRangedSpecialAttack(actor,target,duration,rules,p){
  if(!target)return;
  const data=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255,p.warning);
  const defender=await required(p,'creature')(target)?await p.creature(target):null;
  await required(p,'attackRoll')(actor,target);
  if(attackResultDoesDamage(data.result)){await required(p,'damage')(actor,target);await required(p,'postDamage')(actor,target);}
  else await required(p,'miss')(actor,target);
  await required(p,'animations')(actor,target,duration);
  const leg=data.attackType===65000,arm=data.attackType===65001;
  if((!leg&&!arm)||!attackResultDoesDamage(data.result))return;
  if(totalAttackDamage(data,1)<1||!defender){data.result=6;return;}
  const limb=await required(p,'limb')(defender,leg?'leg':'arm');
  if(!Number.isInteger(limb))throw new Error('Native called-shot limb state is unavailable');
  if(limb!==0){
    const rank=(await required(p,'skill')(defender,3,actor,0)<<24)>>24;
    if(typeof p.random?.next!=='function')throw new Error('Native called-shot random stream is unavailable');
    const draw=p.random.next();if(!Number.isInteger(draw))throw new Error('Native called-shot random draw is unavailable');
    if(((draw%20+1+rank)|0)>=((data.roll+data.modifier)|0)){data.result=5;return;}
    const effect=async(type,integers)=>{
      const value=await required(p,'effect')(type,actor.id,integers,0);
      value.durationType=1;value.duration=rulesetFloat(rules,'CALLED_SHOT_EFFECT_DURATION',24);data.lists[0].push(value);
    };
    if(leg){
      await effect(37,[1,rulesetInt(rules,'CALLED_SHOT_LEG_ABILITY_PENALTY',2),3]);
      await effect(29,[rulesetInt(rules,'CALLED_SHOT_LEG_MOVEMENT_PENALTY',20)]);
    }else await effect(11,[rulesetInt(rules,'CALLED_SHOT_ARM_ATTACK_PENALTY',2),0,28]);
  }else{
    data.lists[3].push(await required(p,'message')(3,{integers:[leg?29:30]}));data.result=6;
  }
}
