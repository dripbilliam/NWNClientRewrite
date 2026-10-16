import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {collectClassAbilities,classAbilityPage,featRadialLeaf,featRadialVariants,selectRadialFeat} from '../src/feat_radial.js';

const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-feat-radial-observations.json',import.meta.url)));
function providers(c){
 const classes=c.classes??[3];
 return {classCount:()=>classes.length,classType:i=>classes[i],classInfo:id=>({id,featCount:(c.classFeats?.[id]??[]).length}),
  classFeat:(cls,i)=>{const f=c.classFeats?.[cls.id]?.[i];return f?{onMenu:1,...f}:null;},
  classDomain:(_i,d)=>(c.classDomains??[0,1])[d],domain:id=>{const d=c.domains?.[id];return d?{castable:0,featId:257,...d}:null;},
  owns:id=>(c.owned??[257]).includes(id&65535)||(c.bonus??[]).includes(id&65535),grouped:()=>classes.length>3||c.grouped,
  feat:id=>c.missingFeats?.includes(id)?null:{nameRef:id+1000,icon:'',successor:-1,spellId:c.spellId??10,targetSelf:c.targetSelf??0,...c.feats?.[id]},
  spell:id=>id<0||c.missingSpells?.includes(id)?null:{nameRef:id+2000,icon:`spell${id}`,featId:(c.childFeats?.[id]??id)<<16,children:id===10?c.children??[]:[]},
  remaining:()=>c.remaining??5,warning:()=>{},self:c.self??true,assignment:c.assignment??false,defensiveStance:c.defensiveStance??0,familiar:c.familiar,
  targetId:(c.self??true)?99:c.targetId??100,controlled:c.controlled??true};
}
test('native class ability collector preserves physical class, owned feat and domain grouping',()=>{
 for(const {case:c,entries}of oracle().collector)assert.deepEqual(collectClassAbilities(providers(c)),entries,JSON.stringify(c));
});
test('native class ability pages preserve domains, successor gaps, duplicate collapse and continuation',()=>{
 for(const {case:c,entries}of oracle().page)assert.deepEqual(classAbilityPage(c.index??0,c.start??0,providers(c)),entries,JSON.stringify(c));
});
test('native feat leaf keeps successor ownership, variants, use gating and special presentation rules',()=>{
 for(const {case:c,entries}of oracle().leaf){const value=c.controlled===false?null:featRadialLeaf(c.packed??257,providers(c));assert.deepEqual(value,entries.length?Object.fromEntries(Object.entries(entries[0]).filter(([k])=>k!=='slot')):null,JSON.stringify(c));}
});
test('native variant menu preserves physical child holes and parent use/target restrictions',()=>{
 for(const {case:c,entries}of oracle().variants)assert.deepEqual(featRadialVariants(257,providers(c)),entries,JSON.stringify(c));
});
test('native radial feat selection distinguishes direct input, retargeting, assignment and compiled modes',()=>{
 for(const {case:c,calls}of oracle().selection)assert.deepEqual(selectRadialFeat(c.packed??257,providers(c)),calls[0]??{mode:'none'},JSON.stringify(c));
});
