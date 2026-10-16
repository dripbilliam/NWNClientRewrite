import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
const byte=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native conversion ${name} is unavailable`);return v&255;};
// LoadClassInfo1402a71ef..1402a7247 only writes +520 on a successful
// CanCastSpontaneously read. CNWClass ctor1402992e0 does not initialize it.
export function classAllowsConversion(o,index,rules){
 const type=creatureRoot(o).ClassList[byte(index,'class')]?.Class??255;if((type&255)===255)return false;
 const entry=intEntry(rules.classes,type&255,'CanCastSpontaneously');if(!entry.found)throw new Error('Native class CanCastSpontaneously reads uninitialized loader storage');return entry.value!==0;
}
// GetNumberMemorizedSpellSlots140405770 and GetSpellsOfLevelReady1404095d0.
// The native slot count and readiness tests both narrow to BYTE.
export function conversionSlots(o,index,level){
 index=byte(index,'class');level=byte(level,'level');
 if(index>=(creatureRoot(o)?.ClassList?.length??0)||level>=10)return [];
 const slots=o.nativeTalentClasses?.[index]?.memorized?.[level];if(!Array.isArray(slots))throw new Error('Native conversion slot storage is unavailable');return slots.slice(0,slots.length&255);
}
export function spellsOfLevelReady(o,index,level){return conversionSlots(o,index,level).reduce((n,row)=>row&&(row.ready&255)!==0&&row.domain===0?(n+1)&255:n,0);}
// The action's level lookup has master/Innate fallback. Player input has its
// own simpler lookup and must not silently share this additional fallback.
export function conversionBaseLevel(o,spell,index,domain,p){
 let level=domain!==0?domain&255:p.level(o,spell.id,index)&255;
 if(level===255){const master=p.spell(spell.master);if(master)level=p.level(o,master.id,index)&255;if(level===255)level=spell.innate&255;}
 return level;
}
// AIActionCastSpell1403af4d3..1403af655. The original marks consumed even
// when this scan finds no usable slot; do not add a synthetic rejection.
export async function consumeConvertedSpell(o,spell,index,domain,meta,p){
 const level=(conversionBaseLevel(o,spell,index,domain,p)+p.metamagicCost(meta&255))&255;
 for(const row of p.slots(o,index,level))if(row&&(row.ready&255)!==0&&row.domain===0)return p.consume(o,row.id,index&255,0,row.metamagic&255,255);
 return 1;
}
