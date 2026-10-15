import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptObjectDistance,scriptFacingVector} from '../src/script_geometry.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {NativeFactionManager} from '../src/faction_manager.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

test('distance is native f32 3D magnitude, compares area pointers and returns minus one for invalid targets',()=>{
  const a={objectType:5,position:[0,0,0]},b={objectType:10,position:[3,12,-4]},area={};
  assert.equal(scriptObjectDistance(a,b,()=>area),13);assert.equal(scriptObjectDistance(a,b,()=>null),13);
  assert.equal(scriptObjectDistance(a,b,o=>o===a?area:null),-1);
  assert.equal(scriptObjectDistance(a,{objectType:4},()=>area),-1);assert.equal(scriptObjectDistance(null,b,()=>area),-1);
  const c={objectType:5,position:[.12345,.98765,-2.34567]};
  const f=Math.fround,[x,z,negativeY]=c.position.map(f),y=f(-negativeY);
  assert.equal(scriptObjectDistance(a,c,()=>area),f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z)))));
});
test('facing points use native XYZ and normalized full 3D orientation, with native class and exact commandable gates',()=>{
  const o={objectType:5,nativeFieldEc:1,position:[2,7,-3]};
  assert.deepEqual(scriptFacingVector(o,[3,3,7],true),[1,0,-0]);
  assert.deepEqual(scriptFacingVector(o,[2,4,7],true),[0,0,-1]);
  assert.equal(scriptFacingVector(o,[2,3,7],true),null);
  o.nativeFieldEc=2;assert.equal(scriptFacingVector(o,[2,4,7],true),null);
  for(const type of [5,6,9,12])assert.ok(scriptFacingVector({...o,objectType:type,nativeFieldEc:1},0,false));
  for(const type of [3,4,7,8,10,11,13,14])assert.equal(scriptFacingVector({...o,objectType:type,nativeFieldEc:1},0,false),null);
});
test('commandability shares one canonical field across script access, requests and DoCommand',()=>{
  const s=new ModuleSession(null),o=s.register('creature','c',{}),d=s.register('door','d',{});
  o.commandable=false;assert.equal(o.nativeFieldEc,0);assert.equal(s.commands.GetCommandable([],{self:o.id}),0);
  o.nativeFieldEc=7;assert.equal(o.commandable,7);assert.equal(s.commands.GetCommandable([o.id]),7);
  s.commands.SetCommandable([-9],{self:o.id});assert.equal(o.nativeFieldEc,1);
  s.commands.SetCommandable([0,d.id]);assert.equal(s.commands.GetCommandable([d.id]),0);
  assert.equal(s.commands.GetCommandable([OBJECT_INVALID]),0);
});
test('faction iteration keeps per-faction cursor, skips stale/non-PC entries and exposes live appends after exhaustion',()=>{
  const s=new ModuleSession(null);s.factionManager=new NativeFactionManager();s.factionManager.createDefaults();
  const a=s.register('creature','a',{factionId:1,nativeStatsIsPCb0:0}),b=s.register('creature','b',{factionId:1,nativeStatsIsPCb0:2});
  const faction=s.factionManager.get(1);faction.members.append(OBJECT_INVALID);faction.members.append(a.id);faction.members.append(b.id);
  assert.equal(s.commands.GetFirstFactionMember([a.id]),b.id);assert.equal(faction.field18,3);
  assert.equal(s.commands.GetNextFactionMember([a.id]),OBJECT_INVALID);assert.equal(faction.field18,3);
  faction.members.append(a.id);assert.equal(s.commands.GetNextFactionMember([b.id,0]),a.id);
  assert.equal(s.commands.GetFirstFactionMember([b.id,0]),a.id);assert.equal(s.commands.GetNextFactionMember([a.id,0]),b.id);
  assert.equal(s.commands.GetFirstFactionMember([OBJECT_INVALID]),OBJECT_INVALID);
});
test('achievement engine call delivers native payload only to a real client and records the missing platform sink',()=>{
  const messages=[],s=new ModuleSession(null,{onCombatMessage:m=>messages.push(m)}),pc=s.register('creature','p',{stats:{}}),npc=s.register('creature','n',{stats:{}});
  s.player=pc;const begin=runtimeDiagnostics.records.length;
  s.commands.UnlockAchievement([npc.id,'test']);assert.equal(messages.length,0);
  s.commands.UnlockAchievement([pc.id,'test',-1,0x80000000,3]);
  assert.deepEqual(messages,[{recipientId:pc.id,type:'achievement',data:{objectIds:[pc.id],strings:['test'],integers:[-1,-2147483648,3]},attack:undefined}]);
  assert.ok(runtimeDiagnostics.records.slice(begin).some(r=>r.code==='engine.achievement-presentation-unimplemented'));
});
