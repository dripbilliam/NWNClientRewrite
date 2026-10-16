// ExecuteCommandDoTouchAttack140516710. Spell touch rolls are distinct from
// weapon attack rolls: no iterative/weapon-critical roll pipeline is invoked.
const i8=v=>(v<<24)>>24,i16=v=>(v<<16)>>16;
export async function spellTouchAttack(ordinal,targetId,feedback,attackerId,p){
  const target=p.object(targetId),attacker=p.object(attackerId);if(!target||!attacker)return 0;
  const actor=p.creature(attacker),victim=p.creature(target);
  let result=0,roll=null,bonus=0,defenseResult=0,concealment=0;
  if(actor&&victim){
    bonus=((await p.attackBonus(actor,ordinal===147))+i8(p.enemyBonus(victim)))|0;
    const ac=i16(await p.armorClass(victim,actor,1));roll=(await p.roll(1,20))&65535;
    if(await p.defensive(actor,target,1)!==0){const data=p.attack(actor);defenseResult=data.result&255;concealment=data.concealmentChance&255;}
    else if(roll!==1){
      if(roll===20)result=(((await p.roll(1,20)&65535)+bonus)|0)>=ac?2:1;
      else if(((roll+bonus)|0)>=ac)result=1;
    }
  }else if(actor){if(target.objectType===9||target.objectType===10)result=1;}
  else if(p.worldObject(attacker)&&victim){
    const ac=i16(await p.armorClass(victim,null,0));bonus=i8(p.enemyBonus(victim));roll=(await p.roll(1,20))&65535;
    if(roll!==1){if(roll===20)result=(((await p.roll(1,20)&65535)+bonus)|0)>=ac?2:1;else if(((roll+bonus)|0)>=ac)result=1;}
  }
  if(feedback===1){
    if(roll===null){await p.indeterminateFeedback(attacker,target);return result;}
    const integers={0:bonus,1:roll};
    if(result===0){integers[2]=defenseResult||4;if(defenseResult)integers[4]=concealment;}
    else integers[2]=result===2?3:1;
    if(ordinal===147)integers[3]=1;
    const message={objects:{0:attackerId>>>0,1:target.id>>>0},integers};
    for(const id of [attackerId,target.id]){const client=p.client(id);if(client)await p.send(client,13,message);}
  }
  return result;
}
