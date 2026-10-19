import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {createAreaVisualState,loadAreaVisualEffect,startAreaVisualEffect,updateAreaVisualEffect} from '../src/area_visual_effect.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {networkVisualIdentity} from '../src/network_visual_presentation.js';
const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
test('complete original area visual loader, phase and AI calls/state match all captured cases',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-visual-observations.json',import.meta.url)));assert.equal(fixture.target,target);assert.equal(fixture.cases.length,928);
 for(const row of fixture.cases){const c=row.case,calls=[],e=Object.assign(createAreaVisualState({day:1,time:2}),c.state);e.position=[1.25,-2,3.5];e.model=c.model===false?null:{};e.sound170=c.sound?{}:null;let destroyed=false;
  const query=key=>{calls.push(['query',key]);return c.entries?.[key]??{found:false,value:0};};
  const p={quality:()=>c.quality??1,int:(_id,key)=>query(key),float:(_id,key)=>query(key),string:(_id,key)=>query(key),
   loadModel:async(_e,name,part,flags)=>{calls.push(['loadModel',name,part,flags]);return c.load??1;},animationMode:(_e,mode)=>calls.push(['animationMode',mode]),defaultAnimation:()=>calls.push(['defaultAnimation']),shake:(...args)=>calls.push(['shake',...args]),speed40:()=>.75,
   oneShot:(...args)=>calls.push(['oneShot',...args]),animationLength:(_e,phase)=>{calls.push(['length',phase]);return c.length??1250.5;},play:(_e,...args)=>calls.push(['play',...args]),
   createSound:name=>{calls.push(['createSound',name]);return{};},sound3d:(_s,v)=>calls.push(['sound3d',v]),soundPriority:(_s,v)=>calls.push(['soundPriority',v]),soundLooping:(_s,v)=>calls.push(['soundLooping',v]),playSound:()=>calls.push(['playSound']),stopSound:()=>calls.push(['stopSound']),destroySound:()=>calls.push(['destroySound']),updateSound:(_s,...args)=>calls.push(['updateSound',...args]),
   now:()=>c.now??{day:2,time:10000},difference:()=>c.difference??{day:0,time:1},setScene:(_e,scene)=>calls.push(['setScene',scene??0]),destroy:()=>{destroyed=true;calls.push(['destroy']);}};
  if(c.kind==='load')assert.equal(await loadAreaVisualEffect(e,c.id,p),row.result);else if(c.kind==='start')startAreaVisualEffect(e,c.phase,p);else updateAreaVisualEffect(e,p);
  const state=Object.fromEntries(Object.keys(row.state).map(key=>[key,key==='sound'?Boolean(e.sound170):key==='since'?e.since:e[key]>>>0]));assert.deepEqual({calls,state,destroyed},{calls:row.calls,state:row.state,destroyed:row.destroyed},JSON.stringify(c));
 }
});
test('captured original summon/unsummon 4/2 packets decode without requiring an object or beam schema',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v64.json',import.meta.url))),packets=capture.wireMessages.filter(h=>h.startsWith('500402'));assert.equal(packets.length,2);
 const decoded=packets.map(h=>decodeServerGameMessage(Uint8Array.from(Buffer.from(h,'hex')),{clientBuild:{number:8193,revision:37,postfix:17}}));assert.deepEqual(decoded.map(v=>v.visualId),[36,99]);assert.ok(decoded.every(v=>v.kind==='area-visual'&&networkVisualIdentity(v.visualTransform)));assert.deepEqual(decoded[0].position,[5,4,0]);
 for(const h of packets){const bytes=Uint8Array.from(Buffer.from(h,'hex'));assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,bytes.length-1),{clientBuild:{number:8193,revision:37,postfix:17}}),/Invalid/);}
});
