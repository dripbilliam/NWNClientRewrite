import { getAttackData } from './combat_attack_data.js';
import { rulesetInt } from './combat_stats.js';

const required=['offhand','creature','attackModifier','armorClass','sneak','death','defensive','rangedEquipped','skillRank','parryAttack','parryIndex','criticalThreat','difficulty','effectImmunity','message'];
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native attack roll ${name} is unavailable`);return value|0;};
// ResolveAttackRoll 0x1403e4100..1403e45e9, normal combat-debugging disabled
// path. Writes the native caller-owned record at the same decision points;
// no precomputed skill/critical/defense queries may change random order.
export async function resolveStrikeRoll(actor,target,rules,p) {
  if(!target)return;
  for(const name of required)if(typeof p[name]!=='function')throw new Error(`Native attack roll provider ${name} is unavailable`);
  if(typeof p.random?.dice!=='function')throw new Error('Native attack roll RNG is unavailable');
  if(p.combatDebugging)throw new Error('Native combat debugging branch is not implemented');
  await p.preflight?.(actor,target);
  const round=actor.combatRound,data=getAttackData(round,round.currentAttack&255,p.warning),offhand=integer(await p.offhand(actor),'offhand'),ranged=data.ranged;
  const roll=integer(p.random.dice(1,20),'d20')&65535,defender=await p.creature(target);
  const modifier=integer(await p.attackModifier(actor,defender,data),'modifier');
  const ac=defender?(integer(await p.armorClass(defender,actor,data),'armor class')<<16)>>16:0;
  if(defender){await p.sneak(actor,defender,data);await p.death(actor,defender,data);}
  data.modifier=modifier;
  if(data.coupDeGrace===1){data.roll=20;data.result=7;return;}
  data.roll=roll;const total=(modifier+roll)|0;
  if(await p.defensive(actor,target,Number(total>=ac),data)===1)return;
  if(defender&&roll!==20&&defender.combatMode===1&&(defender.combatRound.parryActions&255)!==0&&Number(defender.combatRound.paused)===0&&
      (defender.creatureState&255)!==6&&ranged===0&&await p.rangedEquipped(defender)===0){
    const skill=(integer(await p.skillRank(defender,10,actor,0),'parry skill')<<24)>>24;
    const check=((integer(p.random.dice(1,20),'parry d20')&65535)+skill)|0;
    if(total<=check){
      if(total<=((check-rulesetInt(rules,'PARRY_RIPOSTE_DIFFERENCE',10))|0))await p.parryAttack(defender.combatRound,actor.id);
      data.result=2;defender.combatRound.parryActions=(defender.combatRound.parryActions-1)&255;return;
    }
    await p.parryIndex(defender.combatRound);defender.combatRound.parryActions=(defender.combatRound.parryActions-1)&255;
  }
  if(roll===1||total<ac&&roll!==20){data.result=4;data.missedBy=roll===1?1:Math.abs((roll+((modifier-ac)|0))|0)&255;return;}
  if(integer(await p.criticalThreat(actor,offhand),'critical threat')<=roll){
    const confirm=integer(p.random.dice(1,20),'confirmation')&65535;data.threatened=1;data.confirmation=confirm;
    if(ac<=((confirm+modifier)|0)){
      if(!defender){data.result=3;return;}
      const easy=await p.difficulty(0)===1,protectedTarget=Boolean(defender.isPC||defender.isPossessedFamiliar),playerActor=Boolean(actor.isPC||actor.isPossessedFamiliar);
      if(!easy||!protectedTarget||playerActor){
        if(await p.effectImmunity(defender,31,actor,1)===0){data.result=3;return;}
        data.lists[3].push(await p.message(0,{objects:[defender.id],integers:[126]}));
      }
    }
  }
  data.result=1;
}
