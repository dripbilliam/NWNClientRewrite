import { rulesetInt, intEntry } from './combat_stats.js';
import { getAttackData } from './combat_attack_data.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native saving throw ${name} is unavailable`);return v|0;};
const i8=v=>(integer(v,'signed byte')<<24)>>24;
const magical=spell=>spell&&((spell.classification-1)&255)<2;
const required=['baseSave','getObject','asObject','creature','areaEffect','getCreature','spellId','spell','effectBonus','hasFeat','classLevel','canUseSkill','skillRank','trapSource','bonusLimit','immunityTable','effectImmunity','autoFail','message','client','broadcast'];

// GetFortSavingThrow(1) 0x1404024c0 (and corresponding Reflex/Will)
// omit GetTotalEffectBonus, while retaining authored/ability/feat bonuses.
export function savingThrowWithoutEffects(actor,save) {
  const name=({1:'fortitude',2:'reflex',3:'will'})[save&255];
  if(!name)return 0;
  const parts=actor.stats?.combat?.finalBreakdown?.saves?.[name];
  if(!parts)throw new Error('Native saving throw base stat is unavailable');
  return i8(['base','ability','authored','luck','darkBlessing'].reduce((total,key)=>(total+integer(parts[key],key))|0,0));
}

// CNWSCreature::SavingThrowRoll 0x1403ec600..0x1403ed7d8, including
// feedback ownership and the optional immunity table. The entire bonus query
// repeats for Slippery Mind; immunity is checked AFTER consuming the d20.
export async function savingThrowRoll(actor,save,dc,category,versusId,feedback,feat,attackFeedback,rules,p) {
  save=integer(save,'save kind')&255;if(save<1||save>3)return 0;
  dc=integer(dc,'DC')&65535;category=integer(category,'category')&255;versusId=integer(versusId,'versus ID')>>>0;
  feat=integer(feat,'feat')&65535;
  for(const name of required)if(typeof p[name]!=='function')throw new Error(`Native saving throw provider ${name} is unavailable`);
  if(typeof p.random?.dice!=='function')throw new Error('Native saving throw RNG is unavailable');
  await p.preflight?.(actor,save,category,versusId);
  for(;;){
    const base=i8(await p.baseSave(actor,save,1)),versus=await p.getObject(versusId),object=versus?await p.asObject(versus):null;
    let bonus=integer(await p.effectBonus(actor,save,category,object),'effect bonus'),caster=versus?await p.creature(versus):null,aoe=null;
    const add=value=>{bonus=(bonus+integer(value,'bonus'))|0;};
    const rule=(name,fallback)=>rulesetInt(rules,name,fallback);
    const has=id=>p.hasFeat(actor,id);
    const featBonus=async(id,label,fallback)=>{if(await has(id)!==0)add(rule(label,fallback));};
    if(object){
      aoe=await p.areaEffect(object);
      if(aoe&&!caster)caster=await p.getCreature(integer(aoe.creatorId,'area effect creator')>>>0);
      const last=integer(await p.spellId(object),'versus spell');
      if(category!==15&&(last!==-1||aoe&&integer(aoe.spellId,'area effect spell')!==-1)){
        const spell=await p.spell(aoe?aoe.spellId:last);
        if(magical(spell)){
          add(integer(await p.effectBonus(actor,save,15,object),'spell save bonus')-integer(await p.effectBonus(actor,save,0,object),'general save bonus'));
          await featBonus(230,'HARDINESS_SAVE_BONUS',2);
          if(spell.school>=1&&spell.school<=8)await featBonus(414+spell.school,'ARCANE_DEFENSE_SAVE_BONUS',2);
        }
      }
    }
    if(category===1){
      await featBonus(208,'STILL_MIND_COMPETANCE_BONUS',2);
      await featBonus(439,'LLIIRAS_HEART_SAVE_BONUS',2);
      if(await has(241)!==0||await has(236)!==0)add(rule('HARDINESS_SAVE_BONUS',2));
    }else if(category===14)await featBonus(437,'DENEIRS_EYE_SAVE_BONUS',2);
    else if(category===4){
      await featBonus(249,'FEARLESS_MORALE_BONUS',2);
      // Native fallback is two, even though the rule's shipped value differs.
      await featBonus(202,'RESIST_NATURES_LURE_SAVE_BONUS',2);
    }else if(category===2){
      await featBonus(229,'HARDINESS_SAVE_BONUS',2);
      if(await has(1070)!==0)add(Math.trunc(integer(await p.classLevel(actor,30),'Assassin levels')/2));
      else for(let tier=5;tier>=1;tier--)if(await has(462+tier)!==0){add(rule(`POISON_SAVE_BONUS_${tier}`,tier));break;}
      if(save===1){await featBonus(383,'RESIST_POISON_BONUS',4);await featBonus(386,'SNAKE_BLOOOD_POISON_BONUS',2);}
    }else if(category===3)await featBonus(426,'RESIST_DISEASE_BONUS',4);
    else if(category===10)await featBonus(388,'STRONG_SOULD_SAVE_VS_NEG_BONUS',1);
    else if(category===11)await featBonus(388,'STRONG_SOUL_SAVE_VS_DEATH_BONUS',1);
    else if(category===15)await featBonus(230,'HARDINESS_SAVE_BONUS',2);
    if(object&&(category===15||integer(await p.spellId(object),'versus spell')!==-1)&&await p.canUseSkill(actor,16)!==0){
      const divisor=rule('SPELLCRAFT_NUM_RANKS_PER_SAVE_BONUS',5);
      if(!divisor)throw new Error('Native Spellcraft saving throw division fault');
      add(Math.trunc(i8(await p.skillRank(actor,16,object,0))/divisor));
    }
    if(save===2&&versus){
      const trap=await p.trapSource(versus);
      if(trap&&(trap.kind==='placeable'?trap.flag!==0:trap.flag===1)){
        for(let tier=6;tier>=2;tier--)if(await has(249+tier)!==0){
          add(rule(`UNCANNY_DODGE_LEVEL_${tier}`,tier-1));
          if(tier===6){
            const barbarian=integer(await p.classLevel(actor,0),'Barbarian levels'),rogue=integer(await p.classLevel(actor,8),'Rogue levels');
            const levels=barbarian<rogue?integer(await p.classLevel(actor,8),'Rogue levels')-20:barbarian-19;
            if(levels>2)add(Math.trunc(levels/3));
          }
          break;
        }
        if(await has(951)===1)add(rule('DEFENSIVE_AWARENESS_SAVE_BONUS',1));
      }
    }
    bonus=Math.min(bonus,integer(await p.bonusLimit(),'bonus limit'));
    const roll=integer(p.random.dice(1,20),'d20')&65535,table=await p.immunityTable();
    if(table){
      const immune=intEntry(table,category,'Immunity').value;
      if(immune!==0&&await p.effectImmunity(actor,immune&255,caster,1)!==0){
        if(intEntry(table,category,'ImmunityOnlyIfSpell').value===0)return 2;
        if(object){
          const id=integer(await p.spellId(object),'versus spell');
          if((id!==-1||aoe&&aoe.spellId!==-1)&&magical(await p.spell(aoe?aoe.spellId:id)))return 2;
        }
      }
    }else{
      let immune=({1:1,2:2,3:3,4:4,14:5})[category];
      // This build's legacy death-save branch reads the saving actor's spell.
      if(category===11){const id=integer(await p.spellId(actor),'saving actor spell');if(id!==-1&&magical(await p.spell(id)))immune=32;}
      if(immune!==undefined&&await p.effectImmunity(actor,immune,caster,1)!==0)return 2;
    }
    if(feedback!==0||p.savingThrowDebugging){
      const message=await p.message(1,{objects:[actor.id],integers:[dc,(base+bonus)|0,roll,save,category,feat]});
      if(attackFeedback!==0){
        if(!caster?.combatRound)throw new Error('Native saving throw feedback attack owner is unavailable');
        getAttackData(caster.combatRound,caster.combatRound.currentAttack&255,p.warning).lists[3].push(message);
      }else{
        if(await p.client(actor))await p.broadcast(actor,message);
        if(actor.id!==versusId&&caster)await p.broadcast(caster,message);
      }
    }
    const failed=roll===1&&await p.autoFail()!==0||roll!==20&&((roll+bonus+base)|0)<dc;
    if(!failed)return 1;
    if(category!==1||await has(259)===0||feat===259)return 0;
    feat=259;
  }
}
