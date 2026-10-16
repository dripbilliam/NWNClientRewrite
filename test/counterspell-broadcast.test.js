import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {broadcastOrdinarySpellCast,broadcastCounterspellData} from '../src/spell_cast_broadcast.js';
import {selectCounterspell} from '../src/spell_counterspell.js';

test('full spell observation/counterspell feedback matches original native owners and RNG order',async()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-counterspell-broadcast-observations.json',import.meta.url)));
  for(const [kind,rows] of [['broadcast',oracle.broadcasts],['feedback',oracle.feedback]])for(const row of rows){
    const c=row.case,calls=[],objects=new Map([99,100,101,102].map(id=>[id,{id,areaId:id===100?c.areaId??88:88,
      nativeHaste760:id===99?c.haste??0:id===100?c.candidateHaste??0:0,position:[id===99?0:id===100?Math.fround(c.distance??2):id===101?3:50,0,0],
      authored:{ClassList:id===100?[{Class:0,School:c.specialization??0}]:[]},combatMode:id===100?c.mode??4:0,counterSpellTargetId:id===100?c.target??99:0x7f000000}])),
      actor=objects.get(99),viewer=objects.get(100),rules={classes:parse2da(`2DA V2.0\n\nSpellCaster MemorizesSpells PickSchool\n0 1 ${c.memo??1} 1`),
        spells:parse2da(`2DA V2.0\n\nSchool AltMessage\n0 A 0\n1 A ${c.alt??0}`),spellschools:parse2da(`2DA V2.0\n\nOpposition\n0 0\n1 0\n2 ${c.opposition??1}`)},
      spell={id:1,counter1:2,counter2:3,innate:c.innate??1,userType:c.userType??1};
    actor.nativeCounterspellers310=[...(c.initial??[]),...Array(10).fill(0x7f000000)].slice(0,10);actor.nativeCounterCount338=c.initial?.length??0;
    viewer.nativeCounterSpell7fc=0xffffffff;
    const query=(kind,index,id)=>{calls.push([kind,index,id>>>0]);return Number(c.available!==false&&(id>>>0)===(c.counterId??1));};
    const selection={ready:(_o,index,id)=>({count:query('ready',index,id),level:2}),uses:(_o,index,id)=>query('uses',index,id),
      level:(_id,type)=>{calls.push(['level',type]);return 2;},validate:(o,id,index,level)=>{calls.push(['validate',o.id,id>>>0,index,level]);o.nativeCounterSpell7fc=id>>>0;}};
    const p={area:()=>({}),ids:()=>[99,100,101,102],creature:id=>objects.get(id),range:10,visibility:()=>c.visible===false?null:3,
      skill:o=>{calls.push(['skill',o.id]);return c.rank??5;},roll:()=>{calls.push(['roll']);return (c.draw??0)%20+1;},random:()=>{calls.push(['random']);return c.draw??0;},
      client:id=>id===101?null:{id},send:(client,type,data)=>calls.push(['send',client.id,type,{objects:Object.fromEntries(data.objects.map((v,i)=>[String(i),v>>>0])),integers:Object.fromEntries(data.integers.map((v,i)=>[String(i),v>>>0]))}]),
      counterCount:()=>{calls.push(['count']);return c.count??2;},selectCounter:(...args)=>selectCounterspell(...args,rules,selection)};
    if(kind==='broadcast')await broadcastOrdinarySpellCast(actor,spell,rules,p,c.classIndex??0,c.feat??65535);
    else await broadcastCounterspellData(actor,spell,{objects:[99,100],integers:[101,102]},rules,p);
    const context=`${kind} ${JSON.stringify(c)}`;
    assert.deepEqual(calls,row.calls,context);assert.deepEqual(actor.nativeSpellIdentified808??[],row.identified,context);
    assert.equal(actor.nativeCounterCount338,row.count,context);assert.deepEqual(actor.nativeCounterspellers310,row.ids,context);assert.equal(viewer.nativeCounterSpell7fc|0,row.selected,context);
  }
});
