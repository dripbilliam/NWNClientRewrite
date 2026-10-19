import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {ClientPausePresentation,localPauseFields} from '../src/client_pause_presentation.js';
import {addPauseExclusion} from '../src/server_pause.js';
import {advanceLocalClocks} from '../scripts/advance-effect-clock.mjs';
import {serverObjectIdForClient} from '../src/client_projectile_message.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

test('actual server pause deliveries select independent client clocks and preserve animation time through nested exclusion replacement and rebasing',async()=>{
 let p;const messages=[],reports=[],s=new ModuleSession(null,{runStartupScripts:false,onCombatMessage:e=>{messages.push(structuredClone(e));p?.receive(e);}}),actor=s.register('player','controlled',{authored:{},stats:{}}),other=s.register('creature','ordinary',{authored:{},stats:{}});s.player=actor;s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);
 p=new ClientPausePresentation({session:()=>s,report:(...a)=>reports.push(a)});p.flush();assert.equal(p.now(actor.id),0);assert.equal(p.now(other.id),0);const cursor=s.registry.nextObjectId[0],ids=[...s.registry.objects];
 addPauseExclusion(s.nativeServerPause,actor.id,1);await s.setPauseState(1,1);p.flush();advanceLocalClocks(s,1000);p.flush();assert.equal(p.now(actor.id),1000);assert.equal(p.now(other.id),0);assert.deepEqual(p.snapshot().world,{day:7,time:0});assert.deepEqual(p.snapshot().exclusions,[serverObjectIdForClient(actor.id)]);
 addPauseExclusion(s.nativeServerPause,other.id,2);await s.setPauseState(2,1);p.flush();advanceLocalClocks(s,400);p.flush();assert.equal(p.now(actor.id),1000);assert.equal(p.now(other.id),400);assert.deepEqual(p.snapshot().exclusions,[serverObjectIdForClient(other.id)]);
 await s.setPauseState(2,0);p.flush();assert.equal(p.now(actor.id),1000);assert.equal(p.now(other.id),400);advanceLocalClocks(s,100);p.flush();assert.equal(p.now(actor.id),1100);assert.equal(p.now(other.id),400);
 await s.setPauseState(1,0);p.flush();assert.equal(p.now(actor.id),1100);advanceLocalClocks(s,10);p.flush();assert.equal(p.now(actor.id),1110);assert.equal(p.now(other.id),410);assert.equal(p.snapshot().flags,0);assert.deepEqual(p.snapshot().exclusions,[]);
 assert.notEqual(p.state.world,s.worldTimer);assert.notEqual(p.state.timer1,s.nativeServerPause.timer1);assert.notEqual(p.state.timer2,s.nativeServerPause.timer2);assert.equal(s.registry.nextObjectId[0],cursor);for(const[id,o]of ids)assert.equal(s.registry.get(id),o);assert.ok(p.objects.get(serverObjectIdForClient(actor.id))!==actor);
 assert.deepEqual(messages.filter(e=>e.type==='module-pause-state').map(e=>e.data.exclusionIds),[[actor.id],[other.id],[actor.id],[]]);assert.equal(reports.filter(r=>r[0]==='client.pause-clock-undefined').length,2);assert.ok(reports.every(r=>['client.pause-audio-adapter-incomplete','client.pause-gui-adapter-incomplete','client.pause-clock-undefined'].includes(r[0])));
});

test('local pause projection snapshots canonical IDs, preserves invalid ID, narrows scalar fields and retains extra IDs after WORD count wrap',()=>{
 const ids=Array.from({length:65537},(_,i)=>i),data={mask:255,value:-1,exclusionIds:ids},fields=localPauseFields(data);assert.equal(fields.mask,3);assert.equal(fields.value,1);assert.equal(fields.count,1);assert.equal(fields.ids.length,65537);assert.equal(fields.ids[0],0x80000000);ids[0]=0x7f000000;assert.equal(fields.ids[0],0x80000000);assert.deepEqual(localPauseFields({mask:2,value:2,exclusionIds:[0x7f000000]}),{mask:2,value:0,count:1,ids:[0x7f000000]});
});

test('undefined queue-clock polling aggregates every occurrence for its unresolved stamp without flooding the durable journal',()=>{
 const s=new ModuleSession(null,{runStartupScripts:false}),o=s.register('player','queue-poll-aggregate',{authored:{},stats:{}}),begin=runtimeDiagnostics.records.length;
 for(const time of [300,400,500])s.combat.reportUndefinedQueueClock(o,{now:{day:7,time},previous:{day:7,time:1000},status:-2});
 let rows=runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='combat.queue-clock-undefined');assert.equal(rows.length,1);assert.deepEqual(rows[0].context.now,{day:7,time:300});runtimeDiagnostics.flushRepeated();rows=runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='combat.queue-clock-undefined');assert.equal(rows.length,2);assert.equal(rows.reduce((n,r)=>n+r.context.occurrences,0),3);assert.equal(rows[1].context.totalOccurrences,3);
 s.combat.reportUndefinedQueueClock(o,{now:{day:7,time:600},previous:{day:7,time:2000},status:-2});rows=runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='combat.queue-clock-undefined');assert.equal(rows.length,3);assert.equal(rows[2].context.previous.time,2000);assert.equal(rows[2].context.now.time,600);
});
