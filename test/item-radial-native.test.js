import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {itemUseEntries,itemPropertyPage,itemVariantEntries} from '../src/item_radial.js';
const observations=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-radial-observations.json',import.meta.url)));
function fixture(c){
 const warnings=[],item={baseItem:c.baseItem??50,activeProperties:structuredClone(c.properties??Array.from({length:c.count??1},(_,subtype)=>({type:15,subtype,costValue:c.cost??1,remaining:c.remaining??1})))},
 p={baseInfo:()=>c.missingBase?null:{stacking:c.stacking??1},property:(i,n)=>i.activeProperties[n]?{...i.activeProperties[n],subtype:i.activeProperties[n].subtype??n}:null,
  propertyInt:(subtype,col)=>(col==='SpellIndex'?100:10000)+subtype,propertySpell:(_i,index)=>100+index,
  spell:id=>c.missingSpells?.includes(id)?null:{id,nameRef:id,children:id===100?Array.from({length:c.variants??0},(_,n)=>201+n):[]},subRadialSpell:(spell,index)=>spell.children[index],
  icon:spell=>c.missingIcons?.includes(`icon${spell.id}`)?null:`icon${spell.id}`,cachedUses:(_i,index)=>(c.cachedUses??33)+index,text:ref=>`#${ref}`,warning:message=>warnings.push(message),hasLearningClass:()=>c.actor!==false&&Boolean(c.learn)};
 return{item,p,warnings};
}
const normalize=entry=>({slot:entry.slot,kind:entry.kind,icon:entry.icon,uses:entry.uses??null,label:entry.label,
 payload:entry.kind==='more'?entry.start:entry.kind==='learn'?0:(entry.index|(entry.variant<<16))>>>0,disabled:entry.disabled});
test('native item root entries preserve slots, spell identities, uses, active skills and scroll learning',()=>{
 for(const row of observations().root){const c=row.case,f=fixture(c);assert.deepEqual(itemUseEntries(f.item,f.p,c).map(normalize),row.entries,JSON.stringify(c));assert.deepEqual(f.warnings,row.warnings,JSON.stringify(c));}
});
test('native item property pages retain physical indices, cast-only offsets and remaining-use disabling',()=>{
 for(const row of observations().pages){const c=row.case,f=fixture(c);assert.deepEqual(itemPropertyPage(f.item,c.start,f.p,c).map(normalize),row.entries,JSON.stringify(c));}
});
test('native item variants retain child icon/name and packed high-WORD index',()=>{
 for(const row of observations().variants){const c=row.case,f=fixture(c);assert.deepEqual((itemVariantEntries(f.item,c.index,f.p,c)??[]).map(normalize),row.entries,JSON.stringify(c));}
});
