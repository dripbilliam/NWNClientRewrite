import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveSpellInput} from '../src/spell_input.js';
import {conversionSlots,spellsOfLevelReady,consumeConvertedSpell,classAllowsConversion} from '../src/spell_conversion.js';
import {parse2da} from '../src/area.js';
test('spontaneous player conversion admission matches untouched original handler block',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-input-conversion-observations.json',import.meta.url)));
 for(const {case:c,calls:expected} of oracle.rows){
  const calls=[],o={objectType:5},spell={id:1,master:2,targetType:43},master={id:2,metamagic:c.allowedMeta};
  await receiveSpellInput(o,{spellId:1,classIndex:0,domainLevel:c.domain,metamagic:c.meta,spontaneous:c.spontaneous,targetId:100,targetType:43,position:[1,2,3]},
   {spell:id=>id===1?spell:master,classAllowsConversion:()=>c.classType!==255&&c.classAllows!==0,level:()=>c.level,metamagicCost:()=>c.cost,slots:()=>c.slots,
    uses:(_o,...a)=>{calls.push(['uses',...a]);return c.uses;},feedback:(_o,n)=>calls.push(['feedback',n]),actionManager:(_o,n)=>calls.push(['manager',n]),
    addCast:(_o,r)=>calls.push(['cast',r.spellId,r.classIndex,r.domainLevel,r.metamagic,r.spontaneous,r.position,r.targetId,r.location])});
  assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});
test('conversion consumes the first ready non-domain slot at the effective active level',async()=>{
 const slots=Array.from({length:10},()=>[]),o={authored:{ClassList:[{Class:2}]},nativeTalentClasses:[{memorized:slots}]},calls=[];
 slots[3]=[null,{id:20,ready:1,domain:1,metamagic:0},{id:21,ready:0,domain:0,metamagic:0},{id:22,ready:256,domain:0,metamagic:0},{id:23,ready:1,domain:0,metamagic:16},{id:24,ready:1,domain:0,metamagic:2}];
 assert.equal(spellsOfLevelReady(o,0,3),2);assert.deepEqual(conversionSlots(o,254,3),[]);assert.deepEqual(conversionSlots(o,0,255),[]);
 const p={spell:()=>({id:5}),level:(_o,id)=>id===1?255:2,metamagicCost:()=>1,slots:conversionSlots,consume:(_o,...args)=>{calls.push(args);return 1;}};
 assert.equal(await consumeConvertedSpell(o,{id:1,master:5,innate:7},0,0,16,p),1);assert.deepEqual(calls,[[23,0,0,16,255]]);
 calls.length=0;assert.equal(await consumeConvertedSpell(o,{id:1,master:5,innate:7},0,9,16,p),1);assert.deepEqual(calls,[],'empty scan still returns native consumed success');
 assert.equal(await consumeConvertedSpell(o,{id:1,master:5,innate:7},0,0,16,{...p,consume:()=>0}),0);
});
test('conversion reads the active class flag and preserves indeterminate missing-column admission',()=>{
 const o={authored:{ClassList:[{Class:0},{Class:1},{Class:2}]}},rules={classes:parse2da('2DA V2.0\n\nCanCastSpontaneously\n0 0\n1 2\n2 ****')};
 assert.equal(classAllowsConversion(o,0,rules),false);assert.equal(classAllowsConversion(o,1,rules),true);assert.equal(classAllowsConversion(o,255,rules),false);
 assert.throws(()=>classAllowsConversion(o,2,rules),/uninitialized loader storage/);
});
