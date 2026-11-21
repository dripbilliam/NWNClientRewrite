import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {NativeAreaSpatialArray} from '../src/area_spatial.js';
import {NativeIdList} from '../src/native_id_list.js';
import {parse2da} from '../src/area.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

test('live persistent effects share canonical IDs, callbacks, anchor movement and complete removal',async()=>{
  const s=new ModuleSession(null,{runStartupScripts:false}),scripts=[];
  s.scheduler.beforePump=()=>{};s.isDead=()=>false;
  // Script VM execution is a captured lower boundary here. Installed NCS is
  // exercised separately by probe-authored-area-spell-lifecycle.mjs.
  s.program=async name=>({name});s.vm={run:async(program,id)=>{const o=s.registry.get(id);assert.equal(o.objectType,11);scripts.push([program.name,id,o.eventObjects.entering,o.eventObjects.exiting]);}};
  s.areaEffects.tablePromise=Promise.resolve(parse2da('2DA V2.0\n\nLABEL SHAPE RADIUS WIDTH LENGTH ONENTER HEARTBEAT ONEXIT\n700 CUSTOM_CIRCLE C 2 0 0 fixture_enter fixture_pulse fixture_exit'));
  const area=s.register('area','area',{objects:[]}),actor=s.register('creature','actor',{areaId:area.id,position:[0,0,0]});
  area.nativeSubareas=new NativeIdList();area.nativeSpatial=new NativeAreaSpatialArray(s.registry);area.nativeSpatial.insert(actor.id);area.objects.push(actor.id);
  const effect=s.commands.EffectAreaOfEffect([0],{self:OBJECT_INVALID});effect.casterLevel=7;effect.spellId=11;
  await s.effects.applyAtLocation(1,effect,{areaId:area.id,position:[0,0,0],nativeOrientation:[1,0,0]},2);
  const first=[...s.registry.objects.values()].find(o=>o.objectType===11);assert.ok(first);assert.notEqual(first.id,effect.id);assert.equal(first.tag,'custom_circle');
  assert.equal(first.nativeCasterLevel344,7);assert.equal(first.nativeSpellId218,11);assert.equal(first.nativeAreaEffectSpellId,11);assert.equal(first.nativeDuration390,2000);
  assert.equal(s.registry.get(first.id),first);assert.equal(s.commands.GetAreaOfEffectCreator([first.id]),OBJECT_INVALID);
  assert.equal(s.commands.GetFirstInPersistentObject([first.id]),actor.id);assert.equal(s.commands.GetNextInPersistentObject([first.id]),OBJECT_INVALID);
  await s.scheduler.pump();assert.equal(scripts[0][0],'fixture_enter');assert.equal(scripts[0][2],actor.id);
  s.scheduler.time=2000;s.worldTimer.snapshot();await s.areaEffects.update(first);await s.scheduler.pump();
  assert.equal(s.registry.get(first.id),undefined);assert.equal(area.nativeSpatial.indexOf(first.id),-1);assert.equal(area.nativeSubareas.indexOf(first.id),-1);
  assert.equal(actor.nativeSubareaMembership.indexOf(first.id),-1);assert.equal(scripts.at(-1)[0],'fixture_exit');assert.equal(scripts.at(-1)[3],actor.id);
  // A second physical table can change the behavior without new spell code.
  s.areaEffects.tablePromise=Promise.resolve(parse2da('2DA V2.0\n\nLABEL SHAPE RADIUS WIDTH LENGTH ONENTER HEARTBEAT ONEXIT\n123 CUSTOM_OTHER C 3 0 0 fixture_enter fixture_pulse fixture_exit'));
  const attached=s.commands.EffectAreaOfEffect([0],{self:OBJECT_INVALID});await s.effects.apply(1,attached,actor.id,8);
  const live=actor.effects.find(e=>e.id===attached.id),second=s.registry.get(live.objectIds[0]);assert.ok(second);assert.equal(second.tag,'custom_other');assert.equal(second.nativeRadius318,3);
  assert.equal(second.nativeAnchor334,actor.id);assert.equal(actor.nativeFollowingAOEs.indexOf(second.id),0);assert.equal(second.nativeDurationType394,2,'attached lifetime belongs to its parent effect');
  s.setPosition(actor,[1,0,-2],0);s.scheduler.time=2001;s.worldTimer.snapshot();await s.areaEffects.update(second);await s.scheduler.pump();
  assert.deepEqual(second.position,actor.position);assert.equal(s.registry.get(second.id),second);
  s.scheduler.time=8001;s.worldTimer.snapshot();await s.areaEffects.update(second);await s.scheduler.pump();assert.ok(scripts.some(row=>row[0]==='fixture_pulse'&&row[1]===second.id));
  await s.effects.remove(actor.id,attached.id);await s.scheduler.pump();
  assert.equal(s.registry.get(second.id),undefined);assert.equal(actor.effects.length,0);assert.equal(actor.nativeFollowingAOEs.count,0);assert.equal(actor.nativeSubareaMembership.count,0);
  assert.equal(area.nativeSubareas.count,0);assert.equal(s.aiMaster.levels[2].indexOf(second.id),-1);assert.equal(s.registry.get(actor.id),actor);
  assert.equal(s.commands.GetFirstInPersistentObject([OBJECT_INVALID]),OBJECT_INVALID);
  assert.equal(s.commands.GetAreaOfEffectCreator([actor.id]),OBJECT_INVALID);assert.equal(s.commands.GetEffectType([attached]),20);
});
