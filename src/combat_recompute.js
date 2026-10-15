const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native round recomputation ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native round recomputation provider ${n} is unavailable`);return p[n];};
const count=r=>{const n=['onhandAttacks','offhandAttacks','additionalAttacks','bonusEffectAttacks'].reduce((n,k)=>(n+integer(r[k],k))|0,0);return n>1?n&255:1;};
// RecomputeRound140378960. Keep the original future-group reduction,
// including its newCount-currentAttack iteration count and unfiltered scan.
export async function recomputeCombatRound(actor,p){
  const r=actor.combatRound,current=integer(r.currentAttack,'current attack')&255,old=count(r),mode=integer(actor.combatMode,'combat mode')&255;
  let feedback=false;
  if(mode===5){
    let monk=false,disciple=false;
    const classes=required(p,'classes')(actor);
    for(const id of classes){if((id&255)===required(p,'monkClass')())monk=true;else if((id&255)===required(p,'discipleClass')())disciple=true;}
    const right=required(p,'equipped')(actor,16);
    if(right&&(!monk&&!disciple||required(p,'monkWeapon')(right)===0&&await required(p,'hasFeat')(actor,899)===0&&
      (await required(p,'relativeSize')(actor,right)>=0||await p.hasFeat(actor,866)===0))){
      await required(p,'feedback')(actor,188);await required(p,'setMode')(actor,0,1);
    }
  }else if(mode===6){
    const right=required(p,'equipped')(actor,16);feedback=!right||required(p,'ranged')(right)===0||right.baseItem===6||right.baseItem===7;
  }else if(mode<=11&&(0xd8e>>>mode&1)!==0){const right=required(p,'equipped')(actor,16);feedback=Boolean(right&&required(p,'ranged')(right)!==0);}
  if(feedback)await required(p,'feedback')(actor,188);
  await required(p,'initialize')(actor);const next=count(r);
  if(next>=old)return;
  if(current>=next){
    for(let n=0;n<r.actions.length;)if(r.actions[n].nativeActionType===1)r.actions.splice(n,1);else n++;
    return;
  }
  for(let n=0;n<next-current;n++){
    for(let index=0;index<r.actions.length;index++){
      const action=r.actions[index],value=integer(action.count,'action count'),following=r.actions[index+1];
      if(!following){if(value===1)r.actions.splice(index,1);else action.count=(value-1)|0;break;}
      if(integer(following.count,'following count')<value){action.count=(value-1)|0;break;}
    }
  }
}
