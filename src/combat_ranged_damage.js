import {getAttackData,totalAttackDamage} from './combat_attack_data.js';
import {rulesetInt} from './combat_stats.js';
const f=Math.fround,integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ranged post-damage ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native ranged post-damage provider ${n} is unavailable`);return p[n];};
const i16=n=>(n<<16)>>16,i8=n=>(n<<24)>>24;

// ResolvePostRangedDamage1403e97a0..1403e9cb5. This owner is distinct
// from melee: no Cleave/CircleKick/Crippling Strike/Quivering Palm insertion.
export async function resolvePostRangedDamage(actor,target,rules,p){
  if(!target)return;
  const round=actor.combatRound,data=getAttackData(round,round.currentAttack&255,p.warning),hand=data.weaponAttackType;
  const total=totalAttackDamage(data,1),offhand=Number(data.weaponAttackType===2);
  const cast=await required(p,'creature')(target);
  if(!cast){if(i16(await required(p,'hitPoints')(target))<=total&&Number(target.plot)===0)data.killingBlow=1;}
  else{
    const defender=await p.creature(target),hpActor=await p.creature(target);
    if((i16(await p.hitPoints(hpActor))<=total||data.coupDeGrace===1)&&await required(p,'immortal')(defender)===0&&Number(defender.plot)===0)data.killingBlow=1;
    if(data.coupDeGrace===1){
      const to=await required(p,'position')(target),from=await p.position(actor);
      if(![to,from].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))throw new Error('Native ranged coup positions are unavailable');
      const range=rulesetInt(rules,'MAX_RANGED_COUP_DE_GRACE',10),delta=from.map((v,i)=>f(f(v)-f(to[i])));
      const distance=f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]));
      if(distance<=f(Math.imul(range,range)))data.lists[0].push(await required(p,'effect')(19,actor.id,[0,1],0));
    }
    const weapon=await required(p,'attackWeapon')(actor,hand);
    if(data.result===3&&await required(p,'devastatingCritical')(actor,weapon)!==0&&await required(p,'effectImmunity')(defender,31,actor,1)===0&&
      await p.immortal(defender)===0&&data.killingBlow===0){
      const strength=i8(await required(p,'abilityModifier')(actor,'Str')),level=integer(await required(p,'level')(actor),'level')&255;
      const dc=((level>>>1)+rulesetInt(rules,'DEVASTATING_CRITICAL_BASE_DC',10)+strength)&65535;
      if((await required(p,'savingThrow')(defender,1,dc,0,actor.id,1,0,1)&255)===0){
        data.lists[0].push(await p.effect(19,actor.id,[1,1],0));data.result=10;
      }else data.lists[3].push(await required(p,'message')(2,{objects:[target.id],integers:[257]}));
    }
  }
  if(total<1&&Number(round.weaponSucks)===0&&await required(p,'weaponEffective')(actor,target.id,offhand)===0){
    data.lists[3].push(await required(p,'message')(3,{integers:[117]}));round.weaponSucks=1;
  }
}
