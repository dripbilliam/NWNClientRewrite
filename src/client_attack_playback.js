const f=Math.fround;
const bit=(mask,result)=>result<11&&Boolean(mask>>>result&1);
// Object remaining74 is a signed countdown even though GetNext returns UINT.
export function advanceClientAnimationCountdown(remaining,elapsed){const value=((remaining|0)-(elapsed|0))|0;return{remaining:value,expired:value<0};}
// CNWCCreature PlayAnimation1407fc7d0 attack branch. Selection, clip lengths,
// sound and wield effects are presentation providers, never combat resolution.
export function playClientAttack(actor,record,p){
 if(record?.type!==1)return false;
 if([2,4,24,25].includes(p.currentAnimation(actor))&&record.ranged===0&&p.bodyType(actor)===1){
  p.prepareWeapon(actor);p.stopModelMotion(actor);p.pendingAttack(actor,record);return true;
 }
 p.prepareWeapon(actor);
 const animation=p.selectAttack(actor,record),length=p.animationLength(actor,animation);
 p.insert(actor,{animation,duration:record.duration,speed:f(f(length)/f(record.duration)),record,delay:0});
 if(p.random()%3===0)p.bark(actor,11+p.random()%3);
 const target=p.object(record.targetId);
 if(!target||bit(0x4ab,record.result)||![0,1].includes(p.currentAnimation(target))||record.reaction<2)return true;
 const reactionLength=p.animationLength(target,record.reaction),divisor=f(f(record.reactionDuration)+(record.reaction===262?f(record.reactionDelay):0));
 p.insert(target,{animation:record.reaction,duration:record.reactionDuration,speed:f(f(reactionLength)/divisor),record:null,delay:0});return true;
}

// Native creature loader802cc0 registers model event "hit" (e47bb0) with
// handler80e490 and the stable current80-byte action record as userdata. That
// event advances linked attacks, including ranged attacks, before clip end.
export function clientAttackHit(record,p){
 if(!record)return false;
 const target=p.object(record.targetId),actor=p.object(record.sourceId);
 if(!actor||!target||actor.objectType!==5)return false;
 if(record.ranged===0){
  if(bit(0x4aa,record.result)){
   p.sound(actor,record,0);
   if(target.objectType!==5||![0,1].includes(p.currentAnimation(target))){if(p.isDoorOrPlaceable(target)&&record.reaction>1)p.playReaction(target,record.reaction);}
   else if(!record.next&&record.reaction>1)p.playReaction(target,record.reaction);
   if(target.objectType===5){
    const hp=p.hitPoints(target);
    if(hp===undefined)p.unhandled('Native target HP for damage bark is unavailable',target);
    else if(hp>0&&record.killingBlow===0&&(record.damage<<16>>16)!==0&&p.random()%3===0)p.bark(target,14+p.random()%3);
   }
  }else if(([206,207,208,262].includes(p.currentAnimation(target)))&&[2,4].includes(record.result)){
   p.sound(actor,record,0);
   if(p.abortOnParry(actor)!==0){p.weaponEffect(actor,0);if(!p.hasModel(actor,18))p.endAnimation(actor);}
   if(record.next)p.endAnimation(target);
   if(target.objectType===5&&record.weaponAttackType!==7&&p.hasParryWeapon(target))p.parryEffect(actor);
  }
  if(bit(0x4aa,record.result)&&(record.damage<<16>>16)>0&&target.objectType===5)p.impactEffect(target,actor,record);
 }
 if(record.next){p.endAnimation(actor);p.weaponEffect(actor,0);p.playAttack(actor,record.next);p.sound(actor,record,1);}
 return true;
}
