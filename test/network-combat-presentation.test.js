import test from 'node:test';
import assert from 'node:assert/strict';
import {Group} from 'three';
import {NetworkCombatPresentation} from '../src/network_combat_presentation.js';
import {networkAnimationContext} from '../src/network_scene.js';
import {parse2da} from '../src/area.js';
import {nativeAnimationName} from '../src/native_animation.js';
import {nativeAnimationNames} from '../src/native_animation_names.js';
import {ModelAnimator} from '../src/model_animation.js';
import {clientObjectAnimationName} from '../src/client_object_animation.js';
import fs from 'node:fs';

function fixture({microseconds=null}={}){
 const tables={baseitems:parse2da('2DA V2.0\n\nWeaponWield WeaponType WeaponSize %AnimSlashL %AnimSlashR PrefAttackDist\n0 2 3 3 50 50 1.5'),appearance:parse2da('2DA V2.0\n\nSIZECATEGORY HITDIST PREFATCKDIST WEAPONSCALE TARGETHEIGHT ABORTONPARRY\n0 3 .5 1.5 1 H 0')};
 const actor={id:0xffffffff,objectType:5,areaId:10,appearance:{appearance:0,equipment:[{slot:16,item:{baseItem:0}}]},replicated:{animation:0,animationSpeed:1,position:[0,0,0],stats:{classes:[{id:4,level:1}]},hitPoints:{current:10}}},target={...structuredClone(actor),id:0x80000012,replicated:{...structuredClone(actor.replicated),position:[2,0,0]}};
 const objects=new Map([[actor.id,actor],[target.id,target]]),bindings=new Map(),world={areaId:10,registry:{get:id=>objects.get(id)}};
 const names=new Set();for(const side of [0,1,2])for(const id of [200,201,202,203,204,205,263,264,265])names.add(nativeAnimationName(id,{fieldDE:1,fieldDD:3,fieldE0:side}));
 for(const o of objects.values()){
  const root=new Group(),model={modelName:'synthetic',nodes:[],animations:[...new Set(nativeAnimationNames)].map(name=>({name,length:1.2,tracks:[],events:names.has(name)?[{name:'hit',time:.25}]:[]}))},animator=new ModelAnimator(model,root);
  bindings.set(o.id,{models:[{root,animator}],bodyType:1,animation:0});animator.play('pause1',{loop:true});
 }
 const reports=[],p=new NetworkCombatPresentation({world,bindings,tables,pose:o=>({position:o.replicated.position,rotation:0}),context:networkAnimationContext,report:(...a)=>reports.push(a),microseconds});
 for(const o of objects.values())p.base(o,0);
 const record={type:1,sourceId:actor.id,targetId:target.id,duration:916,damage:24,result:3,reactionDelay:0,reaction:14,reactionDuration:250,attackType:0,ranged:0,killingBlow:1,weaponAttackType:1};
 const advance=seconds=>{const steps=Math.ceil(seconds/.01);for(let i=0;i<steps;i++){p.update(.01);for(const b of bindings.values()){const a=b.models[0].animator;a.update(.01*p.speedFor(a));}}};
 return{actor,target,world,bindings,reports,p,record,advance};
}

test('native movement correction and turn cues use the existing timed queue then restore the base without authority changes',()=>{
 const f=fixture(),before=structuredClone(f.actor),b=f.bindings.get(f.actor.id);f.p.movementCue(f.actor,{animation:24,type:6,duration:496});f.advance(.02);assert.equal(b.combat.visual,24);assert.equal(b.combat.queue.count,0);assert.ok(b.combat.current);f.advance(.6);assert.equal(b.combat.visual,0);assert.equal(b.combat.current,null);f.p.movementCue(f.actor,{animation:80});f.advance(.02);assert.equal(b.combat.visual,80);f.advance(1.3);assert.equal(b.combat.visual,0);assert.deepEqual(f.actor,before);assert.equal(f.reports.length,0);
});

test('replicated cast release plays one native500ms action over its mapped looping base without changing server state',()=>{
 const f=fixture(),before=structuredClone([f.actor,f.target]);assert.equal(f.p.base(f.actor,16),false);f.p.receive([{action:'cast-animation',id:f.actor.id,animation:19,record:{type:4,targetType:1,targetId:f.actor.id,spellId:123,position:[0,0,0],field38:500}}]);f.advance(.1);const b=f.bindings.get(f.actor.id);assert.equal(b.combat.base,252);assert.equal(b.combat.visual,19);assert.equal(b.models[0].animator.clip.name,'castup');assert.equal(b.combat.speed,Math.fround(1200/490));f.advance(.6);assert.equal(b.combat.current,null);assert.equal(b.combat.visual,252);assert.deepEqual([f.actor,f.target],before);assert.equal(f.reports.some(r=>r[0]==='network.scene-cast-animation-unhandled'),false);
});
test('multiplayer linked attacks advance on actual model hit events before clip end, then restore the base without mutating server objects',()=>{
 const f=fixture(),before=structuredClone([f.actor,f.target]);f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record,{...f.record}]}]);
 f.advance(.1);assert.equal(f.p.events.filter(e=>e.kind==='play'&&e.objectId===f.actor.id).length,1);
 f.advance(.3);const attacks=f.p.events.filter(e=>e.kind==='play'&&e.objectId===f.actor.id&&!e.loop);assert.equal(attacks.length,2);assert.ok(attacks[1].at-attacks[0].at<.4);
 f.advance(1.5);const hits=f.p.events.filter(e=>e.kind==='hit'&&e.objectId===f.actor.id);assert.equal(hits.length,2);assert.equal(f.bindings.get(f.actor.id).combat.visual,0);assert.equal(f.bindings.get(f.actor.id).combat.queue.count,0);
 assert.deepEqual([f.actor,f.target],before);assert.ok(f.reports.some(r=>r[0]==='network.scene-combat-audio-unhandled'));assert.equal(f.reports.some(r=>r[0]==='network.scene-combat-unhandled'),false);
});

test('server ready updates preserve the active attack while repeated equal groups are played separately',()=>{
 const f=fixture();f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record]}]);f.advance(.1);assert.equal(f.p.base(f.actor,1),true);assert.ok(f.bindings.get(f.actor.id).combat.current);f.advance(1.1);
 f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record]}]);f.advance(1.3);assert.equal(f.p.events.filter(e=>e.kind==='hit'&&e.objectId===f.actor.id).length,2);assert.equal(f.bindings.get(f.actor.id).combat.visual,1);
});

test('moving melee defers until an explicit stationary server state; deleted targets and unbinding never run local combat',()=>{
 const f=fixture();f.p.base(f.actor,4);f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record,{...f.record}]}]);f.advance(.2);assert.equal(f.p.events.length,0);assert.ok(f.bindings.get(f.actor.id).combat.pending);
 f.p.base(f.actor,1);f.target.replicationRemoved=true;f.advance(1.2);assert.equal(f.p.events.filter(e=>e.kind==='play'&&e.objectId===f.actor.id&&!e.loop).length,1);
 const b=f.bindings.get(f.actor.id),animator=b.models[0].animator;assert.equal(animator.eventDispatcher.listeners.length,1);f.p.unbind(b);assert.equal(animator.eventDispatcher.listeners.length,0);assert.equal(f.p.animators.has(animator),false);assert.equal(b.combat.queue.count,0);
});

test('1281 original door/placeable name executions retain their distinct virtual mappings',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-animation-name-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,1281);
 for(const c of fixture.cases)assert.equal(clientObjectAnimationName(c.type,c.id,c),c.value,JSON.stringify(c));assert.throws(()=>clientObjectAnimationName(10,72),/flag is unavailable/);
});

test('a placeable reaction uses damage/default clips and native speed1 without borrowing creature clip names',()=>{
 const f=fixture();f.target.objectType=9;const b=f.bindings.get(f.target.id);f.p.unbind(b);delete b.combat;
 b.models[0].animator.model.animations.push({name:'damage',length:.5,tracks:[],events:[]},{name:'default',length:.5,tracks:[],events:[]});f.target.replicated.animationSpeed=2;
 f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record]}]);f.advance(.5);
 const reaction=f.p.events.find(e=>e.kind==='play'&&e.objectId===f.target.id);assert.ok(reaction);assert.equal(reaction.clip,'damage');assert.equal(reaction.speed,Math.fround(500/490));assert.equal(f.reports.some(r=>r[0]==='network.scene-combat-unhandled'),false);
 f.advance(1);assert.equal(b.models[0].animator.clip.name,'default');
});

test('packet insertion samples the monotonic clock after a slow frame instead of underflowing the native remaining duration',()=>{
 let wall=0n;const f=fixture({microseconds:()=>wall});wall=10_000_000n;f.p.receive([{action:'attack-animation',id:f.actor.id,records:[f.record]}]);wall+=16_000n;f.p.update(10.016);
 const state=f.bindings.get(f.actor.id).combat;assert.equal(state.current.remaining,900);assert.equal(state.speed,Math.fround(1200/900));assert.equal(state.queue.count,0);
});

test('a replicated object base change cancels stale hit cues and preserves the newer door/placeable state',()=>{
 const f=fixture(),o=f.target;o.objectType=10;const b=f.bindings.get(o.id);f.p.unbind(b);delete b.combat;o.replicated.animation=22;const s=f.p.ensure(o);f.p.insert(o,{animation:214,duration:100,speed:1});assert.equal(s.queue.count,1);
 f.p.observeObjectBase(o,50);assert.equal(s.base,50);assert.equal(s.visual,50);assert.equal(s.queue.count,0);assert.equal(s.current,null);assert.equal(o.replicated.animation,22);
});

test('an unsigned overdue reaction expires through the native signed countdown on the following update',()=>{
 const f=fixture(),o=f.target;o.objectType=9;const b=f.bindings.get(o.id);f.p.unbind(b);delete b.combat;b.models[0].animator.model.animations.push({name:'damage',length:.066,tracks:[],events:[]},{name:'default',length:1,tracks:[],events:[]});
 f.p.providers().playReaction(o,214);f.p.providers().playReaction(o,214);f.advance(.2);
 const s=b.combat;assert.equal(s.current,null);assert.equal(s.visual,0);assert.equal(s.queue.count,0);assert.ok(f.p.events.some(e=>e.clip==='damage'&&e.speed<.00001));assert.ok(f.p.events.some(e=>e.kind==='overdue'&&e.signedDuration<0));assert.equal(f.reports.some(e=>e[0]==='network.scene-animation-deadline-missed'),false);
});

test('captured offscreen vanilla run plays real attack/hit/readiness and typed object damage with the original IDs',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v38.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v38-diagnostics.json',import.meta.url)));
 assert.equal(r.connected,true);assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.states.at(-1).phase,'closed');assert.equal(r.offscreen,true);assert.equal(r.gpuDisabled,false);assert.ok(r.paintFrames>1000);
 const last=r.samples.filter(s=>s.combat?.events.length).at(-1).combat,plays=last.events.filter(e=>e.kind==='play'),attack=plays.find(e=>e.objectId===0xffffffff&&!e.loop);assert.ok(attack);assert.equal(attack.clip,'1hslashr');assert.ok(attack.speed>1&&attack.speed<2);assert.ok(last.events.some(e=>e.kind==='hit'&&e.targetId===0x80000012));
 assert.ok(plays.some(e=>e.objectId===0x80000012&&e.clip==='damage'));assert.equal(last.actors.find(a=>a.id===0xffffffff).animation,1);assert.equal(last.actors.find(a=>a.id===0xffffffff).pending,0);assert.ok(last.frameMilliseconds<50);
 assert.equal(d.some(e=>e.severity==='error'||e.code==='network.scene-combat-unhandled'||e.code==='network.scene-animation-unavailable'),false);
 // Retain this investigated rough edge rather than making the test imply a
 // complete reaction lifecycle: duplicate authored events can queue a short
 // second reaction that reaches the original unsigned-overdue path.
 assert.ok(d.some(e=>e.code==='network.scene-animation-deadline-missed'));
});

test('final live signed-countdown fix completes both native attack rounds and expires every short reaction',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v39.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v39-diagnostics.json',import.meta.url))),wire=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-attack-replay-v39.json',import.meta.url)));
 assert.equal(r.connected,true);assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.states.at(-1).phase,'closed');assert.equal(r.offscreen,true);assert.equal(r.gpuDisabled,false);assert.ok(r.paintFrames>1000);assert.equal(wire.attacks.length,2);
 const last=r.samples.filter(s=>s.combat?.events.length).at(-1).combat,events=last.events,attacks=events.filter(e=>e.kind==='play'&&e.objectId===0xffffffff&&!e.loop);assert.equal(attacks.length,2);assert.ok(attacks.every(e=>e.speed>1&&e.speed<1.2));assert.deepEqual(attacks.map(e=>e.clip),['1hslashr','1hslashl']);assert.equal(events.filter(e=>e.kind==='hit'&&e.objectId===0xffffffff).length,5);
 for(const [i,event]of events.entries())if(event.kind==='play'&&event.objectId===0x80000012&&event.speed<.00001){const next=events.slice(i+1).find(e=>e.kind==='play'&&e.objectId===event.objectId);assert.ok(next);assert.ok(next.at-event.at<.04);}
 assert.ok(events.some(e=>e.clip==='dead'));assert.equal(last.actors.find(a=>a.id===0xffffffff).animation,1);assert.ok(last.actors.every(a=>a.pending===0&&a.remaining===null&&!a.deferred));assert.equal(d.some(e=>e.severity==='error'||e.code==='network.scene-combat-unhandled'||e.code==='network.scene-animation-unavailable'),false);
});
