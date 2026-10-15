import {getAttackData} from './combat_attack_data.js';
import {checkActionLengthAtTime} from './combat_timing.js';
import {addReaction,decrementRoundLength} from './combat_round.js';
import {attackResultDoesDamage} from './combat_strike.js';

const f=Math.fround,required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native ranged animation provider ${n} is unavailable`);return p[n];};
const vector=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native ranged animation vector is unavailable');return v.map(f);};
const endpoint=data=>[0x80,0x84,0x88].map(offset=>data.raw.getFloat32(offset,true));
function travel(data,from,base){
  const delta=vector(endpoint(data)).map((v,i)=>f(v-from[i]));
  const squared=f(f(f(delta[0]*delta[0])+f(delta[1]*delta[1]))+f(delta[2]*delta[2]));
  const distance=squared>0?f(Math.sqrt(squared)):0;
  const ms=f(f(distance/([31,59,63].includes(base)?40:55))*1000);
  // CVTTSS2SI r12 uses signed64, then only DWORD/WORD portions escape.
  return Number.isFinite(ms)&&ms>=-9223372036854775808&&ms<9223372036854775808?Number(BigInt(Math.trunc(ms))&0xffffffffn)|0:0;
}

// ResolveRangedAnimations1403e9cc0..1403ea286, including its shield
// miss-to-block branch. Positions/orientations are native XYZ, not render axes.
export async function resolveRangedAnimations(actor,target,duration,p={}){
  if(!target)return;
  if(!Number.isInteger(duration))throw new Error('Native ranged animation duration is unavailable');
  duration|=0;
  const index=actor.combatRound.currentAttack&255,data=getAttackData(actor.combatRound,index,p.warning);
  const weapon=await required(p,'attackWeapon')(actor,data.weaponAttackType),result=data.result;
  data.animationDuration=duration;
  if(attackResultDoesDamage(result))data.reactionAnimation=14;
  if(!weapon){data.reactionDelay=0;return;}
  if(result<11&&(0x4ee>>>result&1)!==0){
    const position=vector(await required(p,'position')(target));
    for(let i=0;i<3;i++)data.raw.setFloat32(0x80+i*4,position[i],true);
  }
  const base=(await required(p,'baseItem')(weapon))>>>0;
  let delay=travel(data,vector(await required(p,'position')(actor)),base);
  if(await required(p,'creature')(target)){
    const defender=await p.creature(target);
    if(!defender.combatRound)throw new Error('Native ranged defender round is unavailable');
    if(!checkActionLengthAtTime(defender.combatRound,actor.id,duration,delay))data.reactionAnimation=1;
    else if(data.result===4){
      const shield=await required(p,'equippedItem')(await p.creature(target),32);
      if(!shield||(await required(p,'weaponType')(shield)&255)!==7)data.reactionAnimation=1;
      else{
        if(typeof p.random?.next!=='function')throw new Error('Native ranged animation random stream is unavailable');
        if((await p.random.next()|0)%3===0){
          delay=travel(getAttackData(actor.combatRound,index,p.warning),vector(await p.position(actor)),base);
          const half=Math.trunc(duration/2),next=await p.creature(target);
          if(checkActionLengthAtTime(next.combatRound,actor.id,duration,(half+delay)|0)){
            data.result=2;data.reactionAnimation=12;data.attackDuration=duration;
            addReaction((await p.creature(target)).combatRound,(delay-half)|0,duration);
            decrementRoundLength((await p.creature(target)).combatRound,duration,false);
            await required(p,'setOrientation')(target,vector(await required(p,'orientation')(actor)).map(v=>f(-v)));
          }
        }
      }
    }else{
      data.attackDuration=duration;
      if(data.result===2)data.reactionAnimation=12;
      addReaction((await p.creature(target)).combatRound,data.result===2?(delay-Math.trunc(duration/2))|0:delay,duration);
      decrementRoundLength((await p.creature(target)).combatRound,duration,false);
    }
  }
  data.reactionDelay=delay;
}
