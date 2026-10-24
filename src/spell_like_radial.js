import {castingSpell,spellStringEntry} from './spell_metadata.js';
import {radialSpellTargetAllowed} from './spell_radial.js';
import {isSpellFamily,spellFamilyChildren} from './spell_family.js';

// CClientSpellMenu innate traversal1409a3e80 and client count1408017c0.
// Seven physical slots [E,W,N,S,NE,SW,SE], continuationNW. Duplicate IDs
// collapse within THIS page, keeping the first caster level. The duplicate
// branch increments the physical cursor TWICE (1409a3fbb and1409a417f).
// Invalid spells still consume a slot; continuation keeps that physical cursor.
export function buildSpellLikeRadial(actor,target,rules,p,{start=0,filter=65535,assignment=false}={}){
  if(!Number.isInteger(start)||start<0)throw new Error('Native ability radial start is unavailable');
  if(!actor)return {title:'Innate abilities',entries:[]};
  const pool=actor.nativeSpellLikeAbilities??(actor.nativeSpellLikeAbilities===null?[]:undefined);if(!Array.isArray(pool))throw new Error('Native ability radial pool is unavailable');
  const entries=[],seen=new Set(),slots=[2,6,0,4,1,5,3];let at=start|0,index=0;
  for(;at<pool.length&&index<7;at++){
    const row=pool[at],id=row.id|0;if(seen.has(id)){at++;continue;}seen.add(id);
    const slot=slots[index++],spell=p.spell?p.spell(id):castingSpell(rules,id);if(!spell)continue;
    const level=row.casterLevel&255,uses=pool.reduce((n,a)=>a.id===row.id&&(a.casterLevel&255)===level&&a.remaining!==0?(n+1)&255:n,0);
    const make=(child,path=[])=>isSpellFamily(rules,child)?{label:p.name('spells',child),icon:spellStringEntry(rules.spells,child,'IconResRef')||'IR_XABILITY',uses,disabled:!assignment&&uses<1,children:()=>({title:p.name('spells',child),entries:spellFamilyChildren(rules,child,path).map((id,slot)=>({...make(id,[...path,child]),slot}))})}:{label:p.name('spells',child),icon:spellStringEntry(rules.spells,child,'IconResRef')||'IR_XABILITY',uses,action:'spellLike.use',system:'spell-like casting',binding:{spellId:child,domainLevel:level},disabled:!assignment&&(!radialSpellTargetAllowed(p.spell?p.spell(child):castingSpell(rules,child),actor,target,filter)||uses<1)};
    if(isSpellFamily(rules,id)){entries.push({...make(id),slot});continue;}
    entries.push({slot,label:p.name('spells',id),icon:spellStringEntry(rules.spells,id,'IconResRef')||'IR_XABILITY',uses,
      action:'spellLike.use',system:'spell-like casting',binding:{spellId:id,domainLevel:level},
      disabled:!assignment&&(!radialSpellTargetAllowed(spell,actor,target,filter)||uses<1)});
  }
  if(at<pool.length)entries.push({slot:7,label:'More abilities',icon:'IR_MORE_SP_AB',start:at,children:()=>buildSpellLikeRadial(actor,target,rules,p,{start:at,filter,assignment})});
  return {title:'Innate abilities',entries};
}
