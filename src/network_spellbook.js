import {talentSpell,castingSpell} from './spell_metadata.js';
import {nextPreparationSpell} from './spell_preparation.js';
import {spellLevelByClass,metamagicLevelCost} from './spell_book.js';
import {intEntry} from './combat_stats.js';

// Read-only adapter for the verified native spellbook iterator. Divine books
// enumerate active rules; restricted books enumerate replicated known IDs.
export function networkPreparationEntries(actor,rules,index,level,meta=0){
 const cls=actor?.replicated?.stats?.classes?.[index];if(!cls)return[];
 const known=(actor.playerState?.spellbooks?.[index]?.known??[]).filter(id=>spellLevelByClass(rules,id,cls.id)===level),state={cursor:0,domain:0},result=[];
 const p={controlled:()=>actor,restricted:type=>intEntry(rules.classes,type,'SpellbookRestricted').value,
  knownCount:()=>known.length,known:(_a,_i,_l,n)=>known[n]??0xffffffff,spell:id=>castingSpell(rules,id),metamagic:s=>{if(!s)throw new Error('Native spellbook contains a missing spell');return s.metamagic;},
  classLevel:(_a,i)=>i<8?actor.replicated.stats.classes[i]?.level??0:0,minCastingLevel:type=>{const e=intEntry(rules.classes,type,'MinCastingLevel');if(!e.found)throw new Error('Native spellbook minimum casting level is unavailable');return e.value;},
  spellCount:()=>rules.spells.orderedRows.length,level:(s,type)=>spellLevelByClass(rules,s.id,type),pickDomains:type=>intEntry(rules.classes,type,'PickDomains').value,
  domain:(_a,_i,n)=>cls.domains?.[n]??n,domainSpell:(domain,l)=>{if(!rules.domains?.orderedRows?.[domain])throw new Error('Native spellbook domain is unavailable');const e=intEntry(rules.domains,domain,`Level_${l}`);return e.found?e.value:-1;}};
 for(;;){const id=nextPreparationSpell(index,cls.id,level,meta,state,p);if(id===-1)break;result.push({id,domain:state.domain,metamagic:meta});}return result;
}
// Client8017c0 counts nonzero entries, not the sum of their ready INTs.
export function networkSpellLikeUses(actor,spellId,casterLevel){return(actor?.playerState?.specialAbilities??[]).reduce((n,a)=>a&&a.spell===spellId&&(a.level&255)===(casterLevel&255)&&a.state!==0?(n+1)&255:n,0);}

// Client7f74d0. This counts already replicated ready records/per-day BYTEs;
// it does not grant spells, spend uses or reproduce the server's cast rules.
export function clientSpellUsesLeft(id,index,domain,meta,p){
 index&=255;domain&=255;meta&=255;if(index>=p.classCount())return 0;
 let spell=p.spell(id);if(!spell)return 0;if(spell.master!==id){id=spell.master;spell=p.spell(id);if(!spell)return 0;}
 let level=domain;if(domain===0){level=p.level(spell,p.classType(index))&255;if(level===255)return 0;}else if(!p.confirmDomain(index,domain,id))return 0;
 level=(level+p.metaCost(meta))&255;if(level>=10)throw new Error('Native client spell level reads outside verified storage');
 if(!p.memorizes(p.classType(index)))return p.usesLeft(index,level)&255;
 const slots=p.memorized(index,level);if(slots.length>255)throw new Error('Native client prepared-spell scan wraps its BYTE cursor');
 let count=0;for(const slot of slots)if(slot&&slot.spell===id&&slot.ready!==0&&(meta===0||(slot.metamagic&meta)!==0))count=(count+1)&255;return count;
}
export function networkSpellUsesLeft(actor,rules,id,index,domain,meta){
 const classes=actor?.replicated?.stats?.classes??[],books=actor?.playerState?.spellbooks??{};
 return clientSpellUsesLeft(id,index,domain,meta,{
  classCount:()=>classes.length,classType:n=>classes[n]?.id??255,spell:id=>talentSpell(rules,id),level:(spell,type)=>spellLevelByClass(rules,spell.id,type),metaCost:mask=>metamagicLevelCost(rules,mask),
  memorizes:type=>intEntry(rules.classes,type,'MemorizesSpells').value!==0,
  confirmDomain:(n,level,id)=>{const cls=classes[n];if(!cls||intEntry(rules.classes,cls.id,'PickDomains').value===0)return false;if(!rules.domains)throw new Error('Native client domain table is unavailable');return(cls.domains??[]).some(d=>{const e=intEntry(rules.domains,d,`Level_${level}`);return e.found&&e.value!==-1&&(e.value>>>0)===id;});},
  usesLeft:(n,level)=>books[n]?.usesLeft?.[level]??0,memorized:(n,level)=>books[n]?.memorized?.[level]??[]
 });
}
