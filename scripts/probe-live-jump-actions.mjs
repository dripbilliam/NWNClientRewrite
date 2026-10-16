import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {addObjectAction} from '../src/object_actions.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
const start=runtimeDiagnostics.records.length,area=s.areas.get('m0q1a'),other=s.areas.get('m0q1d'),
 actor=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.id!==s.player.id&&o.areaId===area.id&&!s.isDead(o));assert.ok(actor);
const bits=v=>{const b=new DataView(new ArrayBuffer(4));b.setFloat32(0,v,true);return b.getInt32(0,true);},
 params=(v,a)=>[v[0],-v[2],v[1]].map(value=>({type:2,value:bits(value)})).concat({type:3,value:a.id}),steps=[],
 snapshot=o=>({id:o.id,areaId:o.areaId,position:[...o.position],orientation:[...o.orientation],queue:[...o.objectActionState.list].map(n=>({id:n.actionId,group:n.groupId})),membership:[...o.nativeSubareaMembership.view()]}),
 run=async()=>s.combat.runActions(actor,...Object.values(s.worldTimer.time()));
await s.combat.clearActions(actor);
const original=actor.id,from=snapshot(actor);addObjectAction(actor.objectActionState,5,40,params([25,0,-15],area));await run();
assert.equal(actor.areaId,area.id);assert.ok(Math.hypot(actor.position[0]-25,actor.position[2]+15)<4);steps.push({kind:'queued-native-point',from,to:snapshot(actor)});
// A real installed vfx_persistent row exercises attached-area-effect ownership,
// not an invented learned spell or authored spell impact success.
const effect=s.commands.EffectAreaOfEffect([0,'','',''],{self:s.player.id});await s.effects.apply(2,effect,actor.id);
const owned=actor.effects.find(e=>e.type===31),aoe=s.registry.get(owned?.objectIds?.[0]);assert.ok(aoe);assert.equal(aoe.nativeAnchor334,actor.id);
addObjectAction(actor.objectActionState,48,41,[{type:3,value:s.player.id},{type:1,value:1}]);await run();if(actor.objectActionState.list.head?.action.actionId===4)await run();
assert.equal(aoe.areaId,actor.areaId);assert.deepEqual(aoe.position,actor.position);assert.ok(actor.nativeFollowingAOEs.indexOf(aoe.id)>=0);assert.ok(actor.nativeSubareaMembership.indexOf(aoe.id)>=0);
steps.push({kind:'queued-native-object-with-attached-aoe',actor:snapshot(actor),aoe:{id:aoe.id,areaId:aoe.areaId,position:[...aoe.position]}});
await s.effects.remove(actor.id,owned.id);await s.scheduler.pump();
await s.combat.clearActions(actor);
addObjectAction(actor.objectActionState,30,50,[{type:2,value:bits(100)}]);
await s.combat.dispatchEvent(actor,{eventId:18,payload:{type:1,group:50,areaId:area.id,position:[28,0,-16],targetId:OBJECT_INVALID}});
assert.ok(Math.hypot(actor.position[0]-28,actor.position[2]+16)<4);assert.ok(![...actor.objectActionState.list].some(n=>n.groupId===50&&n.actionId===30));
steps.push({kind:'forced-point-timeout',actor:snapshot(actor)});
await s.combat.clearActions(actor);addObjectAction(actor.objectActionState,30,51,[{type:2,value:bits(100)}]);
await s.combat.dispatchEvent(actor,{eventId:18,payload:{type:1,group:51,areaId:area.id,position:[0,0,0],targetId:s.player.id}});
assert.ok(Math.hypot(...actor.position.map((v,i)=>v-s.player.position[i]))<4);steps.push({kind:'forced-object-timeout',actor:snapshot(actor)});
await s.combat.clearActions(actor);
const destination=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.areaId===other.id&&!s.isDead(o));assert.ok(destination);
addObjectAction(actor.objectActionState,5,52,params(destination.position,other));await run();
assert.equal(actor.id,original);assert.equal(s.registry.get(original),actor);assert.equal(actor.areaId,other.id);assert.equal(area.nativeSpatial.indexOf(actor.id),-1);assert.ok(other.nativeSpatial.indexOf(actor.id)>=0);
steps.push({kind:'canonical-npc-area-transfer',actor:snapshot(actor),targetId:destination.id});
const p=s.player;addObjectAction(p.objectActionState,5,53,params([27,0,-15],area));await s.combat.runActions(p,...Object.values(s.worldTimer.time()));
assert.equal(p.areaId,area.id);assert.ok(Math.hypot(p.position[0]-27,p.position[2]+15)<4);steps.push({kind:'same-area-player-point',actor:snapshot(p)});
// Both public names represent exactly the same pending native cells.
actor.nativeLastClientArea4f4=other.id;actor.nativePendingAreaPosition4f8=[1,2,3];assert.equal(actor.nativeMovementAreaId,other.id);assert.deepEqual(actor.nativeMovementGoal,[1,3,-2]);
actor.nativeMovementGoal=[4,6,-5];assert.deepEqual(actor.nativePendingAreaPosition4f8,[4,5,6]);
const diagnostics=runtimeDiagnostics.records.slice(start),report={steps,diagnostics,limits:'Installed Prelude objects/geometry and real queued/forced native action bridges. Startup/general AI disabled. AoE installed row0 is an explicit engine fixture. Does not test native PC area handshake, door action points, limbo or authored relocation command wrappers/campaign progression.'};
await fs.writeFile('backups/animations/live-jump-actions.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
// The installed training room has an absent plc_w02 PWK. Native's verified
// empty-mesh fallback remains logged; no unavailable action may hide behind it.
const errors=diagnostics.filter(d=>d.severity==='error');assert.equal(errors.length,1);
assert.equal(errors[0].context.operation,'native-placeable-pwk-missing-empty-mesh');assert.equal(errors[0].message,'Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.');
