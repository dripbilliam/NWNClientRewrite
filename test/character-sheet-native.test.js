import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCharacterStatsUpdate,disposeCharacterStatsUpdate,clearCharacterEffectIcons,createCharacterSheetGUI,setCharacterSheetTarget,permittedCharacterSheet,receiveCharacterSheetInput} from '../src/character_sheet.js';
import {ModuleSession} from '../src/module_session.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-character-sheet-observations.json',import.meta.url)));
const rows=mode=>capture.rows.filter(r=>r.case.mode===mode);

test('decoded character-sheet receiver matches original permission/order/overflow and signed counter changes',()=>{
 for(const r of rows('receive')){
  const c=r.case,calls=[],actors=new Map([11,22].map((id,i)=>[id,{id,nativeField540:c.counts?.[i]??[3,7][i]}])),gui={targetId:c.previous??11,page:2,update:{}},p={
   readChar:()=>{calls.push(['char',8]);return c.page;},readObjectId:()=>{calls.push(['objectId']);return c.target;},
   overflow:()=>{calls.push(['overflow']);return c.overflow??0;},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},
   permitted:(_,id)=>{calls.push(['permission',id]);return c.allowed;},notPermitted:(_,id)=>calls.push(['denied',77,id]),gui:()=>gui,
   creature:id=>{calls.push(['creature',id]);return actors.get(id)??null;},
   setTarget:(g,id)=>{calls.push(['target',id]);g.targetId=id;},clearIcons:()=>calls.push(['clear'])};
  const result=receiveCharacterSheetInput({},c.subtype??1,p);
  assert.deepEqual({result,target:gui.targetId,page:gui.page,counts:[...actors.values()].map(a=>a.nativeField540),calls},{result:r.result,target:r.target,page:r.page,counts:r.counts,calls:r.calls},JSON.stringify(c));
 }
});
test('character-sheet permissions match original self/direct-master/DM and unavailable-client-info checks',()=>{
 for(const r of rows('permission')){
  const c=r.case,calls=[],actors=new Map([[11,{id:11,masterId:0x7f000000}],[22,{id:22,masterId:c.master}]]),p={serverAvailable:()=>c.server,
   creature:id=>{calls.push(['creature',id]);return actors.get(id)??null;},playerInfo:()=>{calls.push(['net'],['info',77]);return c.info?{dm:c.dm}:null;},controlledId:()=>c.controlled};
  assert.equal(permittedCharacterSheet({},c.target,p),r.result,JSON.stringify(c));assert.deepEqual(calls,r.calls,JSON.stringify(c));
 }
});
test('character-sheet target setter matches original update identity, null state and allocation-failure path',()=>{
 for(const r of rows('target')){
  const c=r.case,calls=[],old={name:'oldUpdate'},gui={targetId:c.previous,update:c.hasUpdate?old:null},p={
   dispose:o=>calls.push(['dispose',o.name]),create:()=>{calls.push(['allocate',128]);if(c.failAllocate)return null;calls.push(['create','new0']);return{name:'new0'};}};
  setCharacterSheetTarget(gui,c.target,p);assert.equal(gui.targetId,r.target);assert.equal(gui.update?.name??'null',r.update);assert.deepEqual(calls,r.calls.filter(c=>c[0]!=='free'));
 }
});
test('stats-update constructor matches all initialized native scalar sentinels and active skill BYTE count',()=>{
 for(const r of rows('create')){
  const update=createCharacterStatsUpdate(r.case.skillCount);
  for(let i=0;i<update.scalars.length;i++)if(update.initialized[i])assert.equal(update.scalars[i],r.scalars[i],`offset ${i.toString(16)}`);
  assert.deepEqual(update.skills?[...update.skills]:null,r.skills);assert.deepEqual(update.effectIcons,[]);assert.equal(update.effectIconCapacity,0);assert.deepEqual(update.lists,[[],[]]);assert.equal(update.combat.disposed,undefined);
 }
 const gui=createCharacterSheetGUI(28);assert.equal(gui.targetId,0x7f000000);assert.equal(gui.page,-1);assert.equal(gui.force,1);assert.equal(gui.update.skills.length,28);
});
test('effect-icon clear and stats-update destruction match original reverse release order and retained capacity',()=>{
 for(const r of [...rows('clear'),...rows('dispose')]){
  const c=r.case,u=createCharacterStatsUpdate(c.skills?28:0),calls=[];
  u.effectIcons=c.icons.map(n=>n===null?null:{name:'icon'+n});u.effectIconCapacity=16;if(!c.combat)u.combat=null;
  const combat=u.combat,p={releaseIcon:icon=>{calls.push(['free',icon.name]);icon.disposed=true;}};
  if(c.mode==='clear')clearCharacterEffectIcons(u,p);else disposeCharacterStatsUpdate(u,p);
  assert.equal(u.effectIcons.length,r.count);assert.equal(u.effectIconCapacity,r.capacity);
  assert.deepEqual(calls,r.calls.filter(c=>c[0]==='free'&&/^icon\d+$/.test(c[1])));
  if(c.mode==='dispose'){assert.equal(u.disposed,true);assert.equal(u.skills,null);assert.equal(u.combat,null);if(combat)assert.equal(combat.disposed,true);}
 }
});
test('queued character-sheet requests preserve canonical actor ownership and reject invalid decoded fields',async()=>{
 const actor={id:11},session=Object.create(ModuleSession.prototype);Object.assign(session,{player:actor,registry:new Map([[11,actor]]),pendingPlayerInputs:[],receiveCharacterSheet:r=>r.targetId===11?1:0});
 for(const request of [{page:-1,targetId:11},{page:256,targetId:11},{page:0,targetId:-1},{subtype:256,page:0,targetId:11}])await assert.rejects(session.queuePlayerCharacterSheet(request));
 const accepted=session.queuePlayerCharacterSheet({page:0,targetId:11});await session.drainPlayerInputs();assert.equal(await accepted,1);
 const stale=session.queuePlayerCharacterSheet({page:0,targetId:11});session.player={id:11};await session.drainPlayerInputs();assert.equal(await stale,0);
});
