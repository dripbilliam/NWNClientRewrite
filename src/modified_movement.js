const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native modified movement ${n} is unavailable`);return v|0;};
// Complete ComputeModifiedMovementRate1403889b0..140388d1f. Remove only
// the original internal effects, restarting from the cached type range after
// each ID removal. The two new effects intentionally share the copy ctor ID.
export async function computeModifiedMovement(actor,p){
 let stage=0;const feat=integer(await p.hasFeat(actor,240),'first feat');
 if((feat!==0||((integer(actor.animationState,'base animation')!==0||(integer(actor.nativeField6ec,'detect')&255)===1)&&(actor.nativeField6ec&255)===1))&&integer(await p.hasFeat(actor,240),'second feat')===0)stage=integer(p.rule('MOVEMENT_STAGE_PENALTY_DETECT_MODE',1),'detect rule');
 if((integer(actor.nativeField6ed,'stealth')&255)===1)stage=(stage+integer(p.rule('MOVEMENT_STAGE_PENALTY_STEALTH_MODE',1),'stealth rule'))|0;
 if(integer(actor.nativeEncumbrance970,'encumbrance')===1)stage=(stage+integer(p.rule('MOVEMENT_STAGE_PENALTY_ENCUMBRANCE_HEAVY',1),'heavy rule'))|0;
 if(actor.nativeEncumbrance970===2)stage=(stage+integer(p.rule('MOVEMENT_STAGE_PENALTY_ENCUMBRANCE_OVERLOADED',2),'overloaded rule'))|0;
 for(const type of[59,29]){
  let index=p.start(actor,type);
  while(index<p.effects(actor).length){const effect=p.effects(actor)[index],kind=integer(effect.type,'effect type')&65535;if(kind>type)break;
   if(kind===type&&(integer(effect.durationType,'effect duration')&7)===4&&(type===59?integer(effect.integers[0],'stage flag')===1:(effect.creatorId>>>0)===(actor.id>>>0))){await p.remove(actor,effect.id);index=p.start(actor,type);}
   else index++;
  }
 }
 if(stage>0){const flag=p.create();flag.type=59;flag.durationType=4;await p.creator(flag,actor.id);flag.integers[0]=1;
  if(stage>1){let speed=100;for(let n=1;n<stage&&speed!==0;n++)speed=Math.trunc(speed/2);const slow=p.copy(flag,0);slow.type=29;slow.durationType=4;await p.creator(slow,actor.id);slow.integers[0]=100-speed;await p.apply(actor,slow,0,0);}
  await p.apply(actor,flag,0,0);
 }
}
