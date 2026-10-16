import {OBJECT_INVALID} from './game_object_array.js';
import {featInfo} from './feat_uses.js';
import {intEntry} from './combat_stats.js';
import {castingSpell,talentSpell} from './spell_metadata.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native UseFeat ${name} is unavailable`);return v|0;};

// LoadFeatInfo1402a8800 / ctor1402a1180. ReqAction stores a boolean on a
// successful read; TargetSelf preserves its default after a failed read.
// HostileFeat is written unconditionally from GetINTEntry's output, including
// the table default for missing columns (1402a9bb4..1402a9be1).
export function featActivationInfo(rules,id){
  if(!featInfo(rules,id))return null;id&=65535;
  const spell=intEntry(rules.feat,id,'SpellId'),action=intEntry(rules.feat,id,'ReqAction'),self=intEntry(rules.feat,id,'TargetSelf'),hostile=intEntry(rules.feat,id,'HostileFeat');
  return {spellId:spell.found?spell.value:-1,reqAction:action.found?Number(action.value!==0):1,
    targetSelf:self.found?self.value:0,hostile:hostile.value};
}
export function featActivationSpell(rules,id){const spell=castingSpell(rules,id);return spell?{...spell,children:talentSpell(rules,id).children,featId:intEntry(rules.spells,id,'FeatID').value}:null;}
const endsForm=id=>{
  const a=(id-304)&65535,b=(id-872)&65535;
  return a<39&&((0x7f80000003n>>BigInt(a))&1n)!==0n||b<32&&((0xf4000003>>>b)&1)!==0||((id-1060)&65535)<2;
};

// Complete UseFeat1403a91d0. Numeric feat/mode/variant cases below are
// branches compiled into the target engine; the ordinary behavior, spell,
// successor, uses and target flags come from the active rules and live pools.
export async function useFeat(actor,requested,auxiliary,targetId,areaId,point,p){
  requested=integer(requested,'requested feat')&65535;auxiliary=integer(auxiliary,'auxiliary feat')&65535;targetId=integer(targetId,'target ID')>>>0;
  const id=p.highest(actor,requested)&65535;
  if(p.hasFeat(actor,id)===0)return 0;
  const reject=async code=>{await p.feedback(actor,code);return 0;};
  if((integer(actor.nativeField771,'creature state')&255)===5)return reject(7);
  if(targetId!==OBJECT_INVALID){
    const object=p.object(targetId);
    if(object&&p.asCreature(object)){
      const info=p.feat(id);if(!info)throw new Error('Native hostile feat metadata dereferences unavailable storage');
      if(info.hostile===1&&(p.reaction(actor,targetId)&255)===1)return reject(187);
    }
  }
  if((p.remaining(actor,id)&255)===0)return reject(199);
  const attack=()=>p.addAttack(actor,targetId,0,0,0),special=n=>p.addSpecial(actor,n&65535);
  const pcOrPossessed=()=>integer(actor.nativeField89c,'creature PC field')!==0||p.possessed(actor)!==0;
  const mode=async n=>{if(pcOrPossessed())return 1;await attack();if(p.ranged(actor)===0)await p.setMode(actor,n,0);else await p.feedback(actor,188);return 1;};
  if([19,28,389,390,425,947].includes(id))return mode(({19:3,28:2,389:7,390:8,425:10,947:11})[id]);
  if(id===30){
    if(pcOrPossessed())return 1;
    const item=p.equipped(actor,16);if(!item)return 1;
    if((p.base(item).ranged&255)===0||item.baseItem===6||item.baseItem===7)return 1;
    await attack();await p.setMode(actor,6,0);return 1;
  }
  if(id===204){
    if(pcOrPossessed())return 1;
    let monk=false,other=false;
    for(let index=0;index<(p.classCount(actor)&255);index++){
      if((p.classType(actor,index)&255)===p.monkClass)monk=true;
      else if((p.classType(actor,index)&255)===p.otherFlurryClass)other=true;
    }
    const item=p.equipped(actor,16);
    if(item&&(!(monk||other)||p.base(item).monkWeapon!==1)){
      if((p.base(item).ranged&255)!==0)return 1;
      if(p.hasFeat(actor,899)===0){if(p.relativeSize(actor,item)>=0)return 1;if(p.hasFeat(actor,866)===0)return 1;}
    }
    await attack();await p.setMode(actor,5,0);return 1;
  }
  if([5,9,16,17,23,31,39,296,301,472,882].includes(id)){
    await attack();
    if(id===5){await special(auxiliary===65000||auxiliary===65001?auxiliary:65000+(integer(p.random(),'random')%2));return 1;}
    if(id===39||id===296){if(p.equipped(actor,16))await p.feedback(actor,198);else await special(id);return 1;}
    if(id===882){const item=p.equipped(actor,16);if(!item||p.weaponOfChoice(actor,item.baseItem)===0)await p.feedback(actor,243);else await special(id);return 1;}
    if(p.ranged(actor)===0)await special(id);return 1;
  }
  const info=p.feat(id);
  if(!info||info.reqAction!==0)await p.actionManager(actor,1);
  if(!info){p.warning('CNWSCreature::UseFeat() Invalid Feat');return 1;}
  let spellId=info.spellId|0;
  if(info.targetSelf!==0)targetId=actor.id;
  const target=p.creature(targetId);
  if(target&&integer(target.nativeField97c,'polymorph state')!==0&&endsForm(id)){
    const effect=p.effects(target).find(e=>(e.type&65535)===62);
    if(effect){await p.setEffectInteger(effect,2,1);await p.removeEffect(target,effect.id);}
  }
  if(id===304||((id-340)&65535)<3){
    if(auxiliary>=1004&&auxiliary<=1007)spellId=[399,398,397,400][auxiliary-1004];
    else if(auxiliary===0)spellId=(integer(p.random(),'random')%4+397)|0;
  }
  if(id===305||((id-335)&65535)<5){
    if(auxiliary>=1008&&auxiliary<=1012)spellId=auxiliary-1008+401;
    else if(auxiliary===0)spellId=(integer(p.random(),'random')%5+401)|0;
  }
  if(((id-450)&65535)<5){const item=p.equipped(actor,16);if(!item||item.baseItem!==8&&item.baseItem!==11)return reject(188);}
  if(spellId===0){p.warning('No behaviour defined for this feat!');return 1;}
  const spell=p.spell(spellId);if(!spell)return 1;
  let selectedId=spellId,selected=spell;
  for(const childId of spell.children){const child=p.spell(childId>>>0);if(child&&(child.featId>>16)===auxiliary){selectedId=childId>>>0;selected=child;break;}}
  const position=point===null?[0,0,0]:point.map(Math.fround);
  if(spell.targetType&4){if(point===null)return 0;}else if(targetId===OBJECT_INVALID)return 0;
  if(info.reqAction===0){
    const payload=await p.allocateImpact();if(!payload)return 0;
    Object.assign(payload,{spellId:selectedId|0,featId:id,casterId:actor.id>>>0,targetId,itemId:OBJECT_INVALID,position,script:selected.impactScript});
    const area=p.area(actor);payload.areaId=area?p.area(actor).id:OBJECT_INVALID;
    await p.enqueue(8,actor.id,actor.id,0,payload);
    if(p.hasStats(actor))await p.decrement(actor,id);
    return 1;
  }
  await p.addCast(actor,{spellId:selectedId>>>0,classIndex:255,domainLevel:0,metamagic:0,spontaneous:0,position,targetId,
    location:0,front:0,cheat:0,path:0,instant:0,featId:id,casterLevel:255});
  return 1;
}
