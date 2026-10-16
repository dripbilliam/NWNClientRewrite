import {OBJECT_INVALID} from './game_object_array.js';
import {arcaneSpellFailure} from './arcane_spell_failure.js';
import {rulesetInt,rulesetFloat} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell release ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell release provider ${n} is unavailable`);return p[n](...args);};

// GetSpellFailure140408100 reads nine BYTE cells D7b..D83. Invalid
// school BYTE returns zero, rather than an invented school/default cache.
export function spellFailure(actor,school){
  school=integer(school,'school')&255;if(school>=9)return 0;
  const value=actor.nativeSpellFailuresD7b?.[school];return integer(value,'school failure cache')&255;
}

// AIActionCastSpell1403af660..1403afc63. Defensive casting compares signed
// totals; an active concentration effect uses an unsigned15 threshold.
// Skill messages preserve the roll, signed BYTE rank, DC and outcome.
export async function checkCastConcentration(actor,spell,index,domain,meta,defensive,rules,p,{instant=0}={}){
  const cancel=async(code)=>{
    await call(p,'setAnimation',actor,1);await call(p,'setLock',actor,OBJECT_INVALID);actor.nativeField81c=0;
    if(instant===0&&code!==233)await call(p,'feedback',actor,code);
    if(p.counterFailure)await p.counterFailure(actor,147);
    return false;
  };
  if(defensive===1){
    const level=integer(call(p,'level',actor,spell,index,domain,meta),'defensive spell level')&255;
    const roll=integer(await call(p,'roll',1,20),'defensive roll')&65535;
    const rank=(integer(await call(p,'skill',actor,1,0,0),'concentration rank')<<24)>>24;
    let dc=(rulesetInt(rules,'DEFENSIVE_CASTING_BASE_DC',15)+level)|0;
    const enemy=await call(p,'nearestEnemy',actor,rulesetFloat(rules,'CONCENTRATION_CHECK_RANGE',4),OBJECT_INVALID,1,0);
    if((enemy>>>0)!==OBJECT_INVALID&&integer(call(p,'hasFeat',actor,7),'combat casting feat')===0)dc=(dc+rulesetInt(rules,'CONCENTRATION_CHECK_MELEE_PENALTY',4))|0;
    const success=((rank+roll)|0)>=dc;
    if(!success)await call(p,'failureVisual',actor,(integer(spell.conjureAnimation,'conjure animation')&65535)===2?292:293);
    await call(p,'skillMessage',actor,{objects:{0:actor.id>>>0},integers:{0:270,1:roll,2:rank>>>0,3:dc>>>0,4:0,5:Number(success)}});
    if(!success){await call(p,'feedback',actor,233);return cancel(233);}
    await call(p,'feedback',actor,240);
  }
  if(integer(spell.useConcentration,'concentration flag')===0)return true;
  const effects=call(p,'effects',actor);if(!Array.isArray(effects))throw new Error('Native concentration effect list is unavailable');
  if(!effects.some(e=>(integer(e.type,'effect type')&65535)===18))return true;
  const rank=(integer(await call(p,'skill',actor,1,0,0),'concentration rank')<<24)>>24;
  const roll=integer(await call(p,'roll',1,20),'concentration roll')&65535,total=(rank+roll)>>>0;
  if(instant===0){
    const outcome=total>=15?1:((rank+20)|0)<15?3:0;
    await call(p,'skillMessage',actor,{objects:{0:actor.id>>>0},integers:{0:integer(call(p,'skillName',1),'skill string')>>>0,1:roll,2:rank>>>0,3:15,4:0,5:outcome}});
  }
  return total>=15?true:cancel(65);
}

// AIActionCastSpell1403afc65..1403aff8e, after resource consumption and
// concentration. Armor failure draws even at0%; generic failure draws only
// when nonzero. A failed cast does not refund its consumed slot.
export async function checkSpellReleaseFailure(actor,spell,index,meta,automatic,rules,p,{instant=0}={}){
  index=integer(index,'class index')&255;meta=integer(meta,'metamagic');
  const fail=async(code)=>{
    await call(p,'setAnimation',actor,1);await call(p,'setLock',actor,OBJECT_INVALID);actor.nativeField81c=0;
    if(instant===0)await call(p,'feedback',actor,code);
    if(p.counterFailure)await p.counterFailure(actor,118);
    return false;
  };
  const components=String(spell.components).split('\0')[0];
  if(index!==254&&index!==255&&components.includes('s')&&(meta&32)===0&&!automatic?.automaticStill&&integer(call(p,'arcaneClass',actor,index),'arcane class')!==0){
    const chance=arcaneSpellFailure(actor),roll=integer(await call(p,'roll',1,100),'armor roll')&65535;
    if(roll<=chance)return fail(61);
  }
  if((integer(spell.userType,'user type')&255)!==1)return true;
  const school=integer(call(p,'school',spell),'spell school')&255;
  let chance=Math.max(integer(call(p,'spellFailure',actor,school),'school failure')&255,integer(call(p,'spellFailure',actor,0),'general failure')&255);
  if(components.includes('v')&&meta!==16&&!automatic?.automaticSilent&&(integer(actor.nativeField8d4,'component state')&16)===0)chance=Math.max(chance,20);
  if(chance!==0&&((integer(await call(p,'roll',1,100),'spell roll')&65535)<=chance))return fail(236);
  return true;
}
// AIActionCastSpell1403af22d..1403af3f7, after the caster's area is found.
// An unplaced item carried by the caster bypasses LOS. An unplaced item
// belonging to someone else retains the zero destination initialized here.
export function castReleaseLineOfSight(actor,target,point,p){
 const from=p.position(actor).map(Math.fround);from[2]=Math.fround(from[2]+1);
 let to=[0,0,0];
 if(target&&p.asObject(target)){
  if(p.asItem(target)&&!p.area(target)){
   if((p.possessor(target)>>>0)===(actor.id>>>0))return 1;
  }else{to=p.position(target).map(Math.fround);to[2]=Math.fround(to[2]+1);}
 }else{to=point.map(Math.fround);to[2]=Math.fround(to[2]+1);}
 return p.lineOfSight(from,to,actor.id,target?.id??0x7f000000,1);
}
