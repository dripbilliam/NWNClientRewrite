import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {receiveAssociateCommand,broadcastAssociateCommand} from '../src/associate_command.js';
import {receiveAssociateInput} from '../src/combat_input.js';
import {buildOwnedAssociateActions,buildRadialActions} from '../src/radial_actions.js';
test('associate receive, live broadcast and decoded input match original instruction observations',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-associate-command-observations.json',import.meta.url)));
 for(const row of native.rows){
  const c=row.case,calls=[],actor={id:100,objectType:5,masterId:c.masterId??99,lastAssociateCommand:77,nativeField708:17},
   master={id:99,objectType:5,masterId:99,nativeField910:31,nativeField914:32,nativeField8ac:0},ids=[...(c.ids??[])];let event=null;
  const creature=id=>{calls.push(['creature',id]);if(c.operation==='receive')return c.exists?master:null;
   if(c.operation==='broadcast')return id===100?actor:id===99?master:null;
   return c.exists&&id===(c.resolvedId??100)?id===99?master:actor:null;};
  const receive=(o,n)=>{calls.push(['receive',o.id,n]);if(c.mutate&&ids.length)ids.pop();};
  if(c.operation==='receive')await receiveAssociateCommand(actor,c.command,{
   creature,unsummon:o=>calls.push(['unsummon',o.id]),unpossess:o=>calls.push(['unpossess',o.id]),removeDomination:o=>calls.push(['removeDomination',o.id]),
   expression:(_o,n)=>{calls.push(['expression',n]);return{matches:c.matches};},event:(caller,id,e)=>{event=e;calls.push(['event',0,0,caller,id,10,e.type]);}});
  else if(c.operation==='broadcast')await broadcastAssociateCommand(actor,c.command,{associates:()=>c.list?ids:null,creature,receive});
  else assert.equal(await receiveAssociateInput({}, {clientObject:()=>c.actor===false?null:master,asCreature:o=>o,
   readObjectId:()=>{calls.push(['readObject']);return c.targetId??100;},readInt:()=>{calls.push(['readInt',32]);return c.command;},
   overflow:()=>{calls.push(['overflow']);return c.overflow??0;},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},
   associateId:(_o,a,b)=>{calls.push(['associateId',a,b]);return c.redirectId??100;},creature,receive}),0);
  const label=JSON.stringify(c),ignored=new Set(['allocate','eventConstructor','integer','copy','string','ai']);
  assert.deepEqual(calls,row.calls.filter(c=>!ignored.has(c[0])),label);
  assert.equal(actor.lastAssociateCommand,row.command,label);assert.equal(actor.nativeField708,row.field708,label);
  assert.equal(master.nativeField910,row.field910,label);assert.equal(master.nativeField914,row.field914,label);assert.deepEqual(ids,row.ids,label);
  assert.deepEqual(event?Object.fromEntries(event.integers.map((v,i)=>[i,v])):{},row.integers,label);
  assert.deepEqual(event?Object.fromEntries(event.strings.flatMap((v,i)=>[[i,v]])):{},row.strings,label);
 }
});

test('owned-associate submenus preserve original slots, icons and signed command words',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-owned-associate-radial-observations.json',import.meta.url)));
 for(const row of native.rows){
  const menu=buildOwnedAssociateActions(row.type);
  assert.deepEqual(menu.entries.map(e=>[e.slot,e.icon,e.command??null]),row.entries.map(e=>[e.slot,e.icon,e.callback==='140995f10'?e.argument:null]),`associate type ${row.type}`);
 }
 const actor={id:99,kind:'creature'},summon={id:100,kind:'creature',masterId:99,associateType:4};
 assert.equal(buildRadialActions(summon,actor).entries.find(e=>e.slot===7).children().entries.find(e=>e.slot===3).command,-10);
 assert.deepEqual(buildRadialActions(summon,actor).entries.filter(e=>e.action==='associate.command').map(e=>[e.slot,e.command]),[[0,-4],[2,-3],[3,-5],[4,-2],[5,-7]]);
 assert.equal(buildRadialActions({...summon,masterId:777,ownerId:99},actor).entries.find(e=>e.slot===7).action,'conversation.start');
});
