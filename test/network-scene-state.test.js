import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {NetworkWorld} from '../src/network_world.js';
import {networkCreatureAppearance,networkObjectPose,NetworkScene} from '../src/network_scene.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {Raycaster,Vector3} from 'three';
const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-session-v1.json',import.meta.url)));
test('captured server appearance projects the equipped native armor and palette into the existing model resolver',()=>{
 const world=new NetworkWorld();for(const m of report.messages)world.apply(m);const player=world.registry.get(0xffffffff),data=networkCreatureAppearance(player),armor=player.appearance.equipment.find(e=>e.slot===2).item;
 assert.equal(data.Appearance_Type,1);assert.equal(data.Appearance_Head,1);assert.equal(data.ArmorPart_RFoot,armor.parts[0]);assert.equal(data.BodyPart_Torso,armor.parts[7]);assert.equal(data.BodyPart_Robe,armor.parts[18]);assert.equal(data.Color_Leather1,armor.colors[0]);assert.equal(data.Color_Metal2,armor.colors[5]);assert.equal(player.id,0xffffffff);
});
test('native creation vectors and following quantized yaw produce the same rendered facing in real snapshots',()=>{
 const records=report.messages.filter(m=>m.kind==='object-updates').flatMap(m=>m.records);
 for(const create of records.filter(r=>r.action==='create'&&r.objectType===5)){
  const update=records.find(r=>r.action==='update'&&r.id===create.id&&r.state.orientation?.yaw!==undefined);
  const a=networkObjectPose({replicated:create.state}),b=networkObjectPose({replicated:update.state});let difference=(a.rotation-b.rotation)%(2*Math.PI);if(difference>Math.PI)difference-=2*Math.PI;if(difference< -Math.PI)difference+=2*Math.PI;assert.ok(Math.abs(difference)<0.002);assert.deepEqual(a.position,[create.state.position[0],create.state.position[2],-create.state.position[1]]);
 }
});

test('installed native models render all captured static objects and both assembled creature skeletons without simulation',async t=>{
 const module=new URL('../../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm',import.meta.url),install=new URL('../../FullDecomp/NwnRootInstall',import.meta.url);
 if(!fs.existsSync(module)){t.skip('Read-only installed game resources are unavailable');return;}
 const resolver=await openLocalModule(fileURLToPath(install),fileURLToPath(module));
 const world=new NetworkWorld(),issues=[];for(const m of report.messages)world.apply(m);const area=report.messages.find(m=>m.kind==='client-area').area;
 let disposed=0;const scene=new NetworkScene({world,resolver,report:(...d)=>issues.push(d),loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose:()=>disposed++}),releaseAsset:()=>{}});
 try{
  await scene.loadArea(area);const snapshot=scene.snapshot();assert.equal(snapshot.tiles,9);assert.deepEqual(snapshot.failedObjects,[]);assert.ok(scene.objects.has(0xffffffff));assert.ok(scene.objects.has(0x80000013));
  assert.equal(snapshot.objects.length,19);assert.equal(scene.objects.get(0xffffffff).models.length,20);assert.ok(scene.objects.get(0xffffffff).models[0].root.getObjectByName('Rbicep_g'));
  assert.equal(issues.some(d=>d[0]==='network.scene-object-failed'),false);
  const ground=scene.pick(new Raycaster(new Vector3(6,10,-3),new Vector3(0,-1,0)));assert.ok(ground&&!ground.object);assert.deepEqual(ground.point.toArray(),[6,0,-3]);assert.ok(snapshot.groundTriangles>0);
  assert.ok(scene.objects.get(0x80000002).pickBounds);assert.equal(world.registry.get(0x80000002).pickBounds,undefined);
  // Static area records have no .replicated member; deletion remains explicit.
  const id=area.staticPlaceables[0].id;world.registry.get(id).replicationRemoved=true;await scene.sync();assert.equal(scene.objects.has(id),false);
 }finally{await scene.dispose();assert.ok(disposed>0);assert.equal(scene.instances.size,0);}
});

test('real Electron IPC/renderer capture presents the server area and canonical player with native equipment-selected readiness',()=>{
 const live=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v8.json',import.meta.url)));
 const diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v8-diagnostics.json',import.meta.url)));
 assert.equal(live.connected,true);assert.equal(live.failure,undefined);assert.equal(live.gpuDisabled,false);assert.equal(live.states.at(-1).phase,'closed');
 assert.equal(live.renderer.world.objects,33);assert.equal(live.renderer.world.localObjectId,0xffffffff);assert.equal(live.renderer.scene.tiles,9);assert.equal(live.renderer.scene.objects.length,19);assert.deepEqual(live.renderer.scene.failedObjects,[]);
 const player=live.renderer.scene.objects.find(o=>o.id===0xffffffff);assert.equal(player.models,20);assert.equal(player.animation,1);assert.equal(player.clip,'nwreadyr');
 assert.equal(diagnostics.some(d=>d.severity==='error'||/scene-object-failed|scene-animation-unavailable/.test(d.code)),false);
 for(const code of ['network.game-message-unhandled','network.scene-effect-unhandled','network.scene-robe-unhandled','network.scene-equipment-unhandled'])assert.ok(diagnostics.some(d=>d.code===code));
});
