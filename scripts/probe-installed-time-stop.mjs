import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {createTimeStopFixture} from './create-time-stop-fixture.mjs';
import {advanceLocalClocks} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {ClientPausePresentation} from '../src/client_pause_presentation.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-time-stop-v1.json',report={checks:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),original=await fs.readFile(`${install}/data/lcv/wizard.bic`),seed=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:original}),fixture=createTimeStopFixture(original,seed),messages=[];
 let client;const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>{messages.push(structuredClone(m));client?.receive(m);}}).initialize([],{character:fixture.bytes});await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
 const actor=s.player,other=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==actor&&o.stats&&o.areaId===s.currentArea.id);assert.ok(other);const ids=[...s.registry.objects],cursor=s.registry.nextObjectId[0],begin=runtimeDiagnostics.records.length,scripts=[],trace=[],run=s.runScript.bind(s),effectCall=s.commands.EffectTimeStop;
 client=new ClientPausePresentation({session:()=>s,report:(code,message,context)=>runtimeDiagnostics.record(code,message,context)});client.flush();client.now(actor.id);client.now(other.id);const pump=s.scheduler.pump.bind(s.scheduler);s.scheduler.pump=async()=>{await pump();client.flush();client.now(actor.id);client.now(other.id);};
 s.runScript=(name,id,options)=>{scripts.push({name,id,pauseFlags:s.nativeServerPause.flags,world:s.worldTimer.time(),active:s.activeTimer(id).time()});return run(name,id,options);};s.commands.EffectTimeStop=(args,frame,spec)=>{trace.push({name:'EffectTimeStop',self:frame.self});return effectCall(args,frame,spec);};
 const spell=s.spellBook.castingSpell(fixture.spellId),uses=s.spellBook.uses(actor,fixture.spellId,fixture.classIndex,0,0);assert.equal(uses,1);
 const input=s.queuePlayerCastSpell({spellId:fixture.spellId,classIndex:fixture.classIndex,domainLevel:0,metamagic:0,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await input,1);
 let stop;
 for(let n=0;n<200;n++){
  advanceLocalClocks(s,100);await s.combat.updateNativeFrame(actor);await s.scheduler.pump();stop=actor.effects.find(e=>e.type===64);if(stop)break;
 }
 assert.ok(stop,'authored Time Stop retained');assert.equal(s.nativeServerPause.flags,1);assert.equal(s.spellBook.uses(actor,fixture.spellId,fixture.classIndex,0,0),uses-1);assert.ok(scripts.some(r=>r.name.toLowerCase()===spell.impactScript.toLowerCase()));assert.equal(trace.length,1);assert.deepEqual(s.nativeServerPause.list10100,[actor.id]);
 report.checks.push({check:'ordinary-cast-consumes-imported-ninth-level-slot-and-runs-original-Time-Stop-NCS',spellId:fixture.spellId,script:spell.impactScript,trace,stop:structuredClone(stop),messages:messages.filter(m=>m.type==='module-pause-state')});
 // The isolated NPC has not ticked during conjuring. Consume that pre-stop
 // elapsed interval once before asserting that later frozen frames have0.
 await s.combat.updateNativeFrame(other);
 const frozen=s.worldTimer.time(),active=s.activeTimer(actor.id).time(),clientBefore={actor:client.now(actor.id),other:client.now(other.id),state:client.snapshot()};advanceLocalClocks(s,100);await s.combat.updateNativeFrame(actor);await s.combat.updateNativeFrame(other);await s.scheduler.pump();assert.deepEqual(s.worldTimer.time(),frozen);assert.equal(actor.nativeFrameElapsedD4,100);assert.equal(other.nativeFrameElapsedD4,0);assert.equal(s.activeTimer(other.id),s.worldTimer);assert.equal(client.now(actor.id),clientBefore.actor+100);assert.equal(client.now(other.id),clientBefore.other);assert.notEqual(client.state.world,s.worldTimer);report.checks.push({check:'decoded-pause-notification-selects-independent-client-clocks-and-retains-ordinary-pose-time',before:clientBefore,after:{actor:client.now(actor.id),other:client.now(other.id),state:client.snapshot()}});
 const lightId=s.characterRules.spells.orderedRows.findIndex(r=>/^nw_s0_light$/i.test(String(r.ImpactScript))),light=s.spellBook.castingSpell(lightId),lightUses=s.spellBook.uses(actor,lightId,0,0,0);assert.ok(lightUses>0);
 const next=s.queuePlayerCastSpell({spellId:lightId,classIndex:0,domainLevel:0,metamagic:0,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await next,1);
 for(let n=0;n<120&&!scripts.some(r=>r.name.toLowerCase()===light.impactScript.toLowerCase());n++){advanceLocalClocks(s,100);await s.combat.updateNativeFrame(actor);await s.scheduler.pump();}
 const extra=scripts.find(r=>r.name.toLowerCase()===light.impactScript.toLowerCase());assert.ok(extra);assert.equal(extra.pauseFlags,1);assert.deepEqual(extra.world,frozen);assert.ok(extra.active.time>frozen.time);assert.equal(s.spellBook.uses(actor,lightId,0,0,0),lightUses-1);assert.ok(actor.effects.includes(stop));report.checks.push({check:'ordinary-cantrip-casts-through-active-action-clock-while-Time-Stop-remains-and-world-events-stay-frozen',spellId:lightId,script:extra});
 // Continue through the selected creature frame/effect owner, not a forced
 // unpause or bespoke spell timer. The authored d4 result owns the duration.
 for(let n=0;n<400&&actor.effects.includes(stop);n++){advanceLocalClocks(s,100);await s.combat.updateNativeFrame(actor);await s.scheduler.pump();}
 assert.ok(!actor.effects.includes(stop));assert.equal(s.nativeServerPause.flags,0);assert.deepEqual(s.nativeServerPause.list10100,[]);assert.deepEqual(s.worldTimer.time(),frozen);report.checks.push({check:'active-creature-frame-advances-while-world-and-ordinary-NPC-freeze-and-native-expiry-restores-world',frozen,active,after:s.worldTimer.time()});
 for(let n=0;n<70;n++){advanceLocalClocks(s,100);await s.combat.updateNativeFrame(actor);await s.scheduler.pump();}
 assert.equal(client.state.flags,0);assert.equal(s.registry.nextObjectId[0],cursor);for(const[id,o]of ids)assert.equal(s.registry.get(id),o);runtimeDiagnostics.flushRepeated();report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';report.client=client.snapshot();report.scripts=scripts;report.pendingEvents=s.scheduler.events.map(e=>({targetId:e.targetId,type:e.event.type,day:e.day,time:e.time}));report.loadDiagnostics=runtimeDiagnostics.records.slice(0,begin);
 report.limits='Installed Prelude, canonical player/authored NPC, original impact NCS, ordinary cast admission/slot consumption, real native creature frames and three server clocks through strict effect expiry, with authored delayed script events resumed. Decoded pause messages drive independent client timers, received external exclusion IDs and creature presentation time. Owned in-memory wizard fixture changes class15 to17, INT to at least19 and imports active ninth-level known/prepared spell; not creator/level-up validation. Startup/general AI traversal isolated; native individual player/NPC frames run. No GPU/scene/audio/GUI lower ownership, raw transport, full periodic owners or campaign completion claim. All polling occurrences retained via diagnostic aggregates.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.check),error:report.error,diagnostics:report.diagnostics?.length}));
