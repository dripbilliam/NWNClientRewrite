import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {countCounterspellers,selectCounterspell,validateCounterspell,removeCounterspeller,removeCounterspellRoundActions} from '../src/spell_counterspell.js';

test('counterspell counting and selection match original owners at captured resource-query boundaries',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-counterspell-selection-observations.json',import.meta.url)));
  for(const [kind,rows] of [['count',oracle.counts],['selection',oracle.selections]])for(const row of rows){
    const c=row.case,calls=[],classes=c.classes??[{}],rules={classes:parse2da(`2DA V2.0\n\nSpellCaster MemorizesSpells\n${classes.map((entry,i)=>`${i} ${entry.caster??1} ${entry.memo??1}`).join('\n')}`)},
      actor={id:99,areaId:1,position:[0,0,0],nativeHaste760:c.haste??0},viewer={id:100,areaId:c.areaId??1,position:[Math.fround(c.distance??0),0,0],combatMode:c.mode??4,
        counterSpellTargetId:c.target??99,nativeHaste760:c.candidateHaste??0,authored:{ClassList:classes.map((_,Class)=>({Class}))}},
      spell={id:1,counter1:2,counter2:3,innate:c.innate??1};
    if(c.overrides)rules.ruleset=parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.overrides).map(([key,value],index)=>`${index} ${key} ${value}`).join('\n')}`);
    const query=(kind,index,id)=>{calls.push([kind,index,id>>>0]);return c[kind==='ready'?'ready':'uses']?.[`${index}:${id>>>0}`]??0;};
    const p={area:()=>c.noArea?null:{},ids:()=>Array(c.candidates??1).fill(100),creature:()=>viewer,range:10,
      readyCount:(_o,index,id)=>query('ready',index,id),uses:(_o,index,id)=>query('uses',index,id),
      ready:(_o,index,id)=>({count:query('ready',index,id),level:c.level??2}),validate:(_o,id,index,level)=>{calls.push(['validate',id>>>0,index,level]);viewer.nativeCounterSpell7fc=id>>>0;},
      level:(_id,type)=>{calls.push(['level',type]);return c.level??2;}};
    if(kind==='count')assert.equal(countCounterspellers(actor,spell,rules,p),row.count,JSON.stringify(c));
    else{
      const selected=selectCounterspell(actor,viewer,spell,c.castClass??0,c.feat??65535,c.count??2,c.rank??5,rules,p);
      assert.equal(selected.qualified,row.qualified,JSON.stringify(c));assert.equal(selected.rank>>>0,row.rank,JSON.stringify(c));
      assert.equal((viewer.nativeCounterSpell7fc??0xffffffff)|0,row.selected,JSON.stringify(c));
    }
    assert.deepEqual(calls,row.calls,`${kind} ${JSON.stringify(c)}`);
  }
});

test('counterspeller removal and round cleanup match native holes, duplicate IDs and exact pending state',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-counterspell-selection-observations.json',import.meta.url)));
  for(const [kind,rows] of [['remove',oracle.removals],['round',oracle.rounds]])for(const row of rows){
    const c=row.case,o={nativeCounterspellers310:[...c.ids,...Array(10).fill(0x7f000000)].slice(0,10),nativeCounterCount338:c.count},calls=[];
    if(kind==='remove')removeCounterspeller(o,c.id);
    else removeCounterspellRoundActions(o,{creature:id=>id===100?{}:null,
      pending:actor=>{calls.push(['pending',actor===o?'actor':'viewer']);return actor===o?c.actorPending:c.viewerPending;},remove:actor=>calls.push(['remove',actor===o?'actor':'viewer'])});
    assert.deepEqual(calls,row.calls,`${kind} ${JSON.stringify(c)}`);assert.deepEqual(o.nativeCounterspellers310,row.ids,JSON.stringify(c));assert.equal(o.nativeCounterCount338,row.count,JSON.stringify(c));
  }
});

test('native counterspell validation retains the last matching slot including spent entries and null sentinels',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-counterspell-selection-observations.json',import.meta.url)));
  for(const row of oracle.validations){const c=row.case,o={},slots=c.slots,p={slotCount:()=>slots.length,slotId:(_o,_i,_l,n)=>slots[n]?.id??0xffffffff,
    slotMetamagic:(_o,_i,_l,n)=>slots[n]?.metamagic??255,slotDomain:(_o,_i,_l,n)=>slots[n]?.domain??0};
    validateCounterspell(o,c.id,c.classIndex,c.level,p);
    assert.equal(o.nativeCounterSpell7fc|0,row.id,JSON.stringify(c));assert.deepEqual([o.nativeCounterClass800,o.nativeCounterMeta801,o.nativeCounterDomain802],row.fields,JSON.stringify(c));
  }
});
