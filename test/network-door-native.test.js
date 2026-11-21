import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {walkToWaypointRequest} from '../src/network_player_requests.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {networkDefaultInteraction,networkMenuObject,networkRadialActions} from '../src/network_action_menu.js';
import {NetworkWorld} from '../src/network_world.js';
import {applyNetworkDoorOpenState} from '../src/network_door.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {fileURLToPath} from 'node:url';
const clicks=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-door-click-observations.json',import.meta.url))),flags=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-door-flags-observations.json',import.meta.url)));

test('door transition waypoint matches the original click wrapper and server movement action fields',()=>{
 for(const row of clicks.cases){
  const c=row.case,door={id:0x80000002,objectType:10,replicated:{animation:[22,50,51,72][c.state],hasTransition:c.hasTransition}};
  if(row.decoded){
   assert.equal(networkDefaultInteraction(door),'door.transition');const p=walkToWaypointRequest({areaId:0x80000001,position:[28.125,15.25,-.125],targetId:door.id,sequence:0,run:c.run}),native=Buffer.from(row.packets[0],'hex');
   assert.deepEqual(Buffer.from(p.subarray(0,-1)),native.subarray(0,-1));assert.equal(p.at(-1)&0xf8,native.at(-1)&0xf8);
  }
  if(c.state===1&&c.hasTransition)assert.equal(networkRadialActions(door,{id:0xffffffff,objectType:5}).entries.find(e=>e.slot===2).action,'door.close');
 }
});

test('every replicated flag combination updates lock and transition state like the original client',()=>{
 for(const row of flags.cases){
  const message=decodeServerGameMessage(Buffer.from(row.packet,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}}),state=message.records[0].state;
  assert.equal(message.complete,true);assert.deepEqual(state.interactionFlags,row.flags);assert.equal(state.field424,row.cells['0x184']);assert.equal(state.field428,row.cells['0x188']);assert.equal(state.hasTransition,row.cells['0x1c0']);
  const view=networkMenuObject({id:0x80000002,objectType:10,replicated:state});assert.equal(view.locked,Boolean(row.cells['0x184']));assert.equal(view.lockable,Boolean(row.cells['0x188']));
 }
});

test('later server door flags replace creation-time lock/transition state without changing canonical identity',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-session-v1.json',import.meta.url))),world=new NetworkWorld();for(const m of capture.messages)world.apply(m);const door=world.registry.get(0x80000002),before=door;
 for(const value of [1,0]){const row=flags.cases.find(r=>r.flags.every(v=>v===value)),message=decodeServerGameMessage(Buffer.from(row.packet,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}});world.apply(message);assert.equal(world.registry.get(door.id),before);assert.equal(networkMenuObject(door).locked,Boolean(value));assert.equal(door.replicated.hasTransition,value);}
});

test('native common animation updates preserve door BYTE19c on a dead animation while creation initializes it',()=>{
 assert.equal(applyNetworkDoorOpenState(undefined,72,true),3);assert.equal(applyNetworkDoorOpenState(0,72,false),0);assert.equal(applyNetworkDoorOpenState(1,72,false),1);assert.equal(applyNetworkDoorOpenState(3,22,false),0);
 const door={id:0x80000002,objectType:10,replicated:{animation:72,hasTransition:1,doorOpenState:0}};assert.equal(networkDefaultInteraction(door),null);door.replicated.doorOpenState=1;assert.equal(networkDefaultInteraction(door),'door.transition');
});

test('captured area transition reattaches the same controlled creature when the server omits create and area-ID deltas',async()=>{
 const install=fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/',import.meta.url)),resources=installedNetworkResources({install}),resolver=await openLocalModule(install,await resources.findFile('nwm','Prelude','nwm')),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v18.json',import.meta.url)));
 let generation=0,player,entry,updates=0;for(const hex of capture.wireMessages){
  const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});
  if(m.kind==='client-area'){generation++;if(generation===2){player=world.registry.get(world.localObjectId);entry=m;}}
  world.apply(m);
  if(generation===2&&m.kind==='client-area'){assert.equal(world.registry.get(player.id),player);assert.equal(player.areaId,entry.area.id);assert.deepEqual(player.replicated.position,entry.position);assert.equal(player.replicated.orientation[0],0.976544976234436);}
  if(generation===2&&m.kind==='object-updates')for(const r of m.records.filter(r=>r.id===0xffffffff&&r.action==='update')){updates++;assert.equal(r.state.areaId,undefined);assert.equal(player.areaId,entry.area.id);}
 }assert.ok(updates>0);assert.equal(world.localObjectId,0xffffffff);assert.equal(world.registry.get(0xffffffff),player);assert.equal(player.replicationRemoved,false);
});

test('real vanilla-server door cycle, movement in the next area and return preserve control and canonical identity',()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v19.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v19-diagnostics.json',import.meta.url)));
 assert.equal(r.connected,true);assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.interactions.filter(i=>i.action==='door.transition').length,2);
 const areas=[];for(const s of r.states)if(s.world.areaId!==areas.at(-1))areas.push(s.world.areaId);assert.deepEqual(areas,[0x7f000000,0x80000001,0x80000025,0x80000001]);
 assert.equal(r.renderer.world.localObjectId,0xffffffff);assert.equal(r.renderer.state.areaGeneration,3);assert.equal(r.renderer.state.areaReady,true);assert.equal(r.renderer.scene.tiles,9);assert.ok(r.samples.some(s=>s.scene?.tiles===100));assert.deepEqual(r.renderer.scene.failedObjects,[]);
 const door=r.samples.flatMap(s=>s.server.objects.filter(o=>o.id===0x80000002));assert.ok(door.some(d=>d.locked===1));assert.ok(door.some(d=>d.locked===0&&d.animation===51));const opened=door.findIndex(d=>d.animation===51);assert.ok(door.slice(opened+1).some(d=>d.animation===22&&d.locked===0));
 assert.deepEqual(r.moves.map(m=>[m.result.sequence,m.run]),[[1,true],[2,false]]);for(const m of r.moves)assert.ok(r.samples.some(s=>s.at>=m.at&&s.server.areaId===0x80000025&&s.server.objects.some(o=>o.id===0xffffffff&&Math.hypot(o.position[0]-m.position[0],o.position[1]-m.position[1])<0.03)));
 assert.ok(r.renderer.scene.objects.some(o=>o.id===0xffffffff));assert.equal(r.states.at(-1).phase,'closed');assert.equal(diagnostics.some(d=>d.severity==='error'||/game-message-invalid|record-unhandled|scene-object-failed/.test(d.code)),false);
});
