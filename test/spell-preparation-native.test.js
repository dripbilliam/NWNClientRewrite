import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clearMemorizedSpellSlot,createSpellClassState} from '../src/spell_book.js';
import {receiveSpellPreparationInput,dropPreparation,preparationRequest,nextPreparationSpell} from '../src/spell_preparation.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-preparation-observations.json',import.meta.url)));
test('native clear preserves physical slot count/capacity and deletes only the selected non-null record',()=>{
 for(const row of oracle().clear){const c=row.case,calls=[],pool=Array.from({length:c.count},(_,i)=>c.null?null:{id:100+i});
  // Pool values are irrelevant for invalid class/level paths; construct all
  // physical classes so narrowing to class0/level1 is actually exercised.
  const states=Array.from({length:c.classCount??2},()=>createSpellClassState());for(const s of states)for(let n=0;n<10;n++)s.memorized[n]=pool;
  const o={authored:{ClassList:states.map(()=>({Class:0}))},nativeTalentClasses:states};
  clearMemorizedSpellSlot(o,c.classIndex,c.level,c.slot,{warning:s=>calls.push(['warning',s]),deleteSlot:r=>calls.push(['delete',r.id,16])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(pool.map(v=>v?.id??null),row.slots,JSON.stringify(c));assert.equal(pool.length,c.count);
 }
});
test('decoded native prepare16 and clear17 preserve read order, actor veto, widths, guards and return0',async()=>{
 for(const row of oracle().input){const c=row.case,calls=[],actor={nativeField8ac:c.field8ac??0};let cursor=0,overflow=0;const values=c.values??(c.clear?[0,1,0]:[0,100,1,0,2]);
  const p={clientObject:()=>{calls.push(['clientObject']);return c.missingObject?null:actor;},asCreature:()=>{calls.push(['asCreature']);return c.wrongType?null:actor;},
   overflow:()=>{const v=(c.overflows??[0,0])[Math.min(overflow++,1)];calls.push(['overflow',v]);return v;},underflow:()=>{calls.push(['underflow',c.underflow??0]);return c.underflow??0;},
   readByte:()=>{const v=values[cursor++]&255;calls.push(['byte',v]);return v;},readDword:()=>{const v=values[cursor++]>>>0;calls.push(['dword',v]);return v;},
   spell:id=>{calls.push(['spell',id]);return c.missingSpell?null:{};},set:(_o,...args)=>{calls.push(['set',...args]);return c.setResult??1;},clear:(_o,...args)=>calls.push(['clear',...args])};
  assert.equal(await receiveSpellPreparationInput(null,c.clear,p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('native spell-slot drops copy known records, exchange physical slots, and retain native domain/meta behavior',async()=>{
 for(const row of oracle().drop){const c=row.case,calls=[],defaults={id:100,kind:0,level:1,ready:1,metamagic:0,domain:0,classIndex:2},dest={...defaults,...c.destination},source=c.same?dest:{...defaults,...c.source,type:c.sourceType};
  const p={set:(o,id,send,domain,metamagic,classIndex)=>{calls.push(['setWidget',o===dest?'destination':'source',id>>>0,send,domain,metamagic,classIndex]);Object.assign(o,{id,domain,metamagic,classIndex});},tint:o=>{if(!c.missingIcon)calls.push(['tint',o===dest?'destination':'source']);}};
  assert.equal((await dropPreparation(dest,source,c.flags,p))>>>0,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([dest.ready,c.same?1:source.ready],row.ready,JSON.stringify(c));
 }
});
test('domain preparation request subtracts active metamagic cost with BYTE widths',()=>{
 assert.deepEqual(preparationRequest({classIndex:257,id:-1,slot:258,domain:1,level:1,metamagic:4},{metamagicCost:m=>(assert.equal(m,4),3)}),{classIndex:1,spellId:0xffffffff,slot:2,domainLevel:254,metamagic:4});
 assert.equal(preparationRequest({classIndex:0,id:100,slot:0,domain:0,level:3,metamagic:4},{metamagicCost:()=>assert.fail()}).domainLevel,0);
});
test('native preparation list enumerates restricted known pools, unrestricted class levels and distinct domains',()=>{
 for(const row of oracle().list){const c=row.case,state={cursor:c.cursor??0,domain:7},p={controlled:()=>c.missingActor?null:{},restricted:()=>c.restricted??0,
  knownCount:()=>(c.known??[0,1,2]).length,known:(_o,_i,_l,n)=>(c.known??[0,1,2])[n],spell:id=>id<4?{id}:null,metamagic:s=>(c.masks??[0,1,3,63])[s.id],
  classLevel:(_o,i)=>i<8?c.classLevel??3:0,minCastingLevel:()=>c.minimum??1,spellCount:()=>4,level:s=>(c.levels??[0,1,1,2])[s.id],pickDomains:()=>c.pickDomains??1,domain:(_o,_i,n)=>n,domainSpell:n=>(c.domains??[2,3])[n]};
  assert.deepEqual({result:nextPreparationSpell(c.index??0,0,c.level??1,c.meta??0,state,p)>>>0,...state},{result:row.result,cursor:row.cursor,domain:row.domain},JSON.stringify(c));
 }
});
test('queued preparation stays with its original controlled actor, area and session',async()=>{
 for(const change of ['control','area','cancel']){const s=new ModuleSession(null),actor=s.register('creature','actor',{}),other=s.register('creature','other',{});s.player=actor;actor.areaId=1;
  s.spellBook.inputPreparation=()=>assert.fail('Discarded preparation reached authority');const result=s.queuePlayerSpellPreparation({classIndex:0,spellId:100,slot:0,domainLevel:0,metamagic:0});
  if(change==='control')s.player=other;else if(change==='area')actor.areaId=2;else s.cancelPendingPlayerInputs();await s.drainPlayerInputs();assert.equal(await result,0);
 }
});
