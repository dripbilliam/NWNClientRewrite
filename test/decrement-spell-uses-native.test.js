import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptDecrementSpellUses} from '../src/script_spell_uses.js';
import {createSpellClassState,memorizedSlotId,memorizedSlotDetails,memorizedSlotCount,spellClassInfo,decrementSpellsPerDayLeft,spellLikeReady,spellLikeCasterLevel,setSpellLikeReady} from '../src/spell_book.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-decrement-spell-uses-observations.json',import.meta.url)));
function fixture(c){return{creatureData:{ClassList:c.classes.map(entry=>({Class:entry.id}))},nativeTalentClasses:c.classes.map(entry=>({...createSpellClassState(),memorized:structuredClone(entry.pools),perDay:entry.perDay.map(n=>n&255)})),nativeSpellLikeAbilities:structuredClone(c.abilities)};}
const states=o=>o.nativeTalentClasses.map(state=>state.perDay);

test('decrement spell uses matches complete original wrapper selection, ordering, widths and ignored lower failures',async()=>{
 let count=0;
 for(const row of oracle.rows.filter(r=>r.case.mode==='wrapper')){
  const c=row.case,o=fixture(c),calls=[],warnings=[],classRules=new Map(c.classes.map(entry=>[entry.id&255,entry]));
  const p={pop:type=>{calls.push(['pop',type]);return{ok:Boolean(type==='object'?c.popObject:c.popInt),value:type==='object'?c.objectId:c.id};},
   spell:id=>{calls.push(['spell',id]);const spell=c.spells[id];return spell?{id,...spell,spontaneouslyCast:spell.spontaneouslyCast??0}:null;},
   creature:id=>{calls.push(['creature',id]);return c.creature?o:null;},stats:actor=>{assert.equal(actor,o);return o;},classCount:()=>c.classes.length&255,
   classType:(_s,index)=>{calls.push(['classType',index]);return c.classes[index]?.id??255;},classFlag:(type,name)=>classRules.get(type)[name==='SpellCaster'?'caster':'memo'],
   uses:(_s,id,index,domain,meta)=>{calls.push(['uses',id,index,domain,meta]);return c.uses[index]??0;},level:(spell,type)=>{calls.push(['level',spell.id,type]);return spell.levels?.[type]??spell.level??1;},
   decrementDay:(_s,index,level)=>{calls.push(['decrementDay',index,level]);decrementSpellsPerDayLeft(o,index,level,{warning:message=>warnings.push(message)});},
   ready:(_s,index,id)=>{calls.push(['ready',index,id]);if(index>7){warnings.push('nMultiClass < CNUMMULTICLASS');return{count:0,level:255,slot:255};}return c.ready[`${index}:${id}`]??{count:0,level:255,slot:255};},
   slotId:(_s,index,level,slot)=>{calls.push(['slotId',index,level,slot]);return memorizedSlotId(o,index,level,slot,{warning:message=>warnings.push(message)});},
   slotCount:(_s,index,level)=>{calls.push(['slotCount',index,level]);return memorizedSlotCount(o,index,level);},
   classInfo:(_s,index)=>{calls.push(['classInfo',index]);return spellClassInfo(o,index);},
   details:(state,level,slot)=>{calls.push(['details',o.nativeTalentClasses.indexOf(state),level,slot]);return memorizedSlotDetails(state,level,slot,{warning:message=>warnings.push(message)});},
   unready:(_s,id,index,domain,meta)=>{calls.push(['unready',id,index,domain,meta]);return c.unreadyResult;},
   abilityReady:(_s,id)=>{calls.push(['abilityReady',id]);return spellLikeReady(o,id);},abilityLevel:(_s,id)=>{calls.push(['abilityLevel',id]);return spellLikeCasterLevel(o,id);},setAbilityReady:(_s,id,ready,level)=>{calls.push(['setAbilityReady',id,ready,level]);return setSpellLikeReady(o,id,ready,level);}};
  assert.equal(await scriptDecrementSpellUses(p)>>>0,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(warnings,row.warnings,JSON.stringify(c));assert.deepEqual(states(o),row.perDay,JSON.stringify(c));assert.deepEqual(o.nativeSpellLikeAbilities,row.abilities,JSON.stringify(c));count++;
 }
 assert.equal(count,497);
});

test('selected spellbook accessor and BYTE decrement bodies match original memory, warning and mutation results',()=>{
 let count=0;
 for(const row of oracle.rows.filter(r=>r.case.mode!=='wrapper')){
  const c=row.case,o=fixture(c),warnings=[],p={warning:message=>warnings.push(message)};let result,output=null;
  if(c.mode==='slotId')result=memorizedSlotId(o,c.index,c.level,c.slot,p);
  if(c.mode==='slotCount')result=memorizedSlotCount(o,c.index,c.level);
  if(c.mode==='classInfo'){const state=spellClassInfo(o,c.index);output=state?o.nativeTalentClasses.indexOf(state):null;}
  if(c.mode==='details')output=memorizedSlotDetails(o.nativeTalentClasses[c.index],c.level,c.slot,p);
  if(c.mode==='decrementDay')decrementSpellsPerDayLeft(o,c.index,c.level,p);
  if(result!==undefined)assert.equal(result>>>0,row.result,JSON.stringify(c));assert.deepEqual(output,row.output,JSON.stringify(c));assert.deepEqual(warnings,row.warnings,JSON.stringify(c));assert.deepEqual(states(o),row.perDay,JSON.stringify(c));count++;
 }
 assert.equal(count,330);
});
