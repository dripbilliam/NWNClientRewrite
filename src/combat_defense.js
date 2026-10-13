import { rulesetInt } from './combat_stats.js';
import { creatureAlignment, creatureRoot } from './creature_rules.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native defense ${name} is unavailable`);return value|0;};
const at=(effect,index)=>(effect.integers[index]??0)|0;
// ResolveDefensiveEffects 0x1403e5630..1403e604d: miss chance is the
// attacker's type 75; concealment/invisibility are the defender's 76/47.
// The input arrays preserve native type order (including equal-type order).
export async function defensiveChances(actor,target,data,rules,p) {
  let missChance=0,concealment=0;
  for(const effect of await p.effects(actor)) {
    if(effect.type>75)break;if(effect.type!==75)continue;
    const type=at(effect,1);
    const applies=type===1?Boolean(integer(target.visionFlags,'defender vision flags')&2):type===2?data.ranged!==0:type===3?data.ranged===0:true;
    if(applies&&missChance<at(effect,0))missChance=at(effect,0);
  }
  const subject=creatureAlignment(creatureRoot(actor));
  for(const effect of await p.effects(target)) {
    if(effect.type>76)break;
    const matches=(at(effect,1)===(subject.race&65535)||at(effect,1)===28)&&(!at(effect,2)||at(effect,2)===subject.lawChaos)&&(!at(effect,3)||at(effect,3)===subject.goodEvil);
    if(!matches)continue;
    if(effect.type===47) {
      const flags=integer(actor.visionFlags,'attacker vision flags');
      if((at(effect,0)===2?(flags&6):(flags&5))===0)concealment=rulesetInt(rules,'INVISIBILITY_CONCEALMENT_CHANCE',50);
    }else if(effect.type===76&&concealment<at(effect,0)) {
      const type=at(effect,4);if(type===0||type===(data.ranged!==0?2:3))concealment=at(effect,0);
    }
  }
  for(const [feat,tier] of [[752,50],[751,40],[750,30],[749,20],[748,10]])if(await p.hasFeat(target,feat)!==0){
    const amount=rulesetInt(rules,`EPIC_SELF_CONCEALMENT_${tier}`,tier);if(concealment<amount)concealment=rulesetInt(rules,`EPIC_SELF_CONCEALMENT_${tier}`,tier);break;
  }
  return{missChance,concealment};
}
export async function resolveDefensiveEffects(actor,target,wouldHit,data,rules,p) {
  if(target.objectType!==5)return 0;
  for(const name of ['effects','hasFeat','flatFooted','equippedItem','rangedWeapon','relativeWeaponSize','savingThrow'])
    if(typeof p[name]!=='function')throw new Error(`Native defense provider ${name} is unavailable`);
  if(typeof p.random?.dice!=='function')throw new Error('Native defense RNG is unavailable');
  await p.preflight?.(actor,target,data);
  const{missChance,concealment}=await defensiveChances(actor,target,data,rules,p);
  if(missChance>0||concealment>0){
    let roll=integer(p.random.dice(1,100),'chance die')&65535;
    const chance=missChance<concealment?concealment:missChance;
    if(roll<chance&&await p.hasFeat(actor,408)!==0)roll=integer(p.random.dice(1,100),'blind fight die')&65535;
    if(roll<chance){data.result=missChance<concealment?8:9;data.concealmentChance=chance;data.missedBy=1;return 1;}
  }
  if(wouldHit===1&&data.ranged===1&&Number(target.combatRound.deflectArrow)===1&&await p.flatFooted(target)===0&&await p.hasFeat(target,8)!==0){
    const right=await p.equippedItem(target,16),left=await p.equippedItem(target,32);
    if(!right||!left&&await p.rangedWeapon(right)===0&&await p.relativeWeaponSize(target,right)<1){
      target.combatRound.deflectArrow=0;
      const dc=rulesetInt(rules,'DEFLECT_ARROWS_DC',20)&65535;
      if((await p.savingThrow(target,2,dc,0,actor.id,1,8,1)&255)===1&&await p.equippedItem(actor,16)){
        // Native computes an unused local projectile vector/magnitude here.
        // No attack position is written; +74 marks the arrow deflection.
        data.result=2;data.deflected=1;return 1;
      }
    }
  }
  return 0;
}
