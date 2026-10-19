import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptItemACValue,scriptSkillSuccessful,skillNameReference} from '../src/script_checks.js';
import {parse2da} from '../src/area.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-checks-observations.json',import.meta.url)));
test('skill-name cache follows original constructor/default records, Name stores, fixed256 allocation and BYTE row count',()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='nameCtor'))assert.equal(row.name,-1);
 for(const row of data.rows.filter(r=>r.case.mode==='nameLoad'))assert.equal(row.name,row.case.name);
 const table=parse2da('2DA V2.0\n\nName\n99 343\n88 -1');assert.equal(skillNameReference(table,0),343);assert.equal(skillNameReference(table,1),-1);assert.equal(skillNameReference(table,254),-1);assert.equal(skillNameReference(table,255),-1);
 table.orderedRows[0].Name='500';assert.equal(skillNameReference(table,0),343,'loaded native records remain cached until a rules reload');assert.equal(skillNameReference(parse2da('2DA V2.0\n\nName\n99 500'),0),500);
 const wrapped=parse2da('2DA V2.0\n\nName\n'+Array.from({length:256},(_,i)=>`${i} ${i+100}`).join('\n'));assert.equal(skillNameReference(wrapped,0),-1);assert.throws(()=>skillNameReference(table,-1),/allocated array256/);
});
test('item AC wrapper matches original cached base, passive WORD sums, wrapping and dynamic/null traversal',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='armor')){
  const c=row.case,trace=[],properties=(c.properties??[[1,2],[1,3],[2,99]]).map(([type,costValue])=>({type,costValue}));let count=c.count??properties.length,output;
  const result=await scriptItemACValue({pop:type=>{trace.push(['pop',type]);return{ok:c.failPop!==0,value:c.id??0x80000042};},push:value=>{output=value>>>0;trace.push(['push',output]);return c.push??1;},item:id=>{trace.push(['item',id]);return c.exists===false?null:{};},baseArmor:()=>c.base??4,passiveCount:()=>count,passive:(_o,index)=>{trace.push(['property',index]);if(c.shrink)count=0;return c.nullProperty===index?null:properties[index];}});
  assert.equal(result>>>0,row.result,JSON.stringify(c));assert.equal(output,row.output??undefined,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('skill success matches original signed gates, rank BYTE, die WORD, message classification, invalid-target DC and VM status',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='skill')){
  const c=row.case,trace=[],args=[c.id??0x80000042,c.skill??1,c.dc??15],actor={id:c.id??0x80000042};let index=0,output;
  const result=await scriptSkillSuccessful({pop:type=>{trace.push(['pop',type]);const i=index++;return{ok:i!==c.failPop,value:args[i]};},push:value=>{output=value>>>0;trace.push(['push',output]);return c.push??1;},lookup:id=>{trace.push(['lookup',id]);return{status:c.status??0,object:actor};},asCreature:o=>{trace.push(['cast']);return c.creature===false?null:o;},rank:(o,skill,versus,flag)=>{trace.push(['rank',skill,versus??0,flag]);return c.rank??5;},dice:(n,d)=>{trace.push(['dice',n,d]);return c.roll??10;},newData:()=>{trace.push(['allocate',72]);return{};},skillName:i=>c.name??260+i,setObject:(_data,i,v)=>trace.push(['object',i,v>>>0]),setInteger:(_data,i,v)=>trace.push(['integer',i,v>>>0]),broadcast:()=>trace.push(['broadcast'])});
  assert.equal(result>>>0,row.result,JSON.stringify(c));assert.equal(output,row.output??undefined,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
