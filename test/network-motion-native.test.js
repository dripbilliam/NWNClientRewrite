import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {clientMotionDistance,stepClientPath,correctClientMotion,NetworkMotion} from '../src/network_motion.js';
import {NetworkPlayerCamera} from '../src/network_camera.js';
import {Vector3,PerspectiveCamera} from 'three';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkScene} from '../src/network_scene.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
test('3933 original client movement frames agree on distance, waypoint cursor, acceleration and correction',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-motion-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,3933);
 for(const row of fixture.cases){const c=row.case,s={...structuredClone(c),walkRate:c.rate,runRate:c.rate,cursor:0,orientation:[1,0,0]},d=clientMotionDistance(s,c.dt),step=stepClientPath(s,d.distance,p=>p[2]);s.position=step.position;s.render=correctClientMotion(s,step.position,c.dt);
  for(const [key,actual,expected]of [['position',step.position,row.position],['render',s.render,row.render]])for(let i=0;i<3;i++)assert.ok(Math.abs(actual[i]-expected[i])<2e-5,JSON.stringify({key,i,c,actual,expected}));assert.equal(s.cursor,row.cursor);assert.ok(Math.abs((step.done?0:s.acceleration)-row.acceleration)<2e-6,JSON.stringify({c,acc:s.acceleration,native:row.acceleration}));assert.equal(s.correction,row.correction);
 }
});
test('native camera follows displayed movement and possession while retaining chosen distance and yaw',()=>{
 const camera=new PerspectiveCamera(),controls={target:new Vector3()},world={localObjectId:0xffffffff},objects=new Map([[world.localObjectId,{wrapper:{position:new Vector3(1,0,1)}}],[0x80000002,{wrapper:{position:new Vector3(5,0,6)}}]]),follow=new NetworkPlayerCamera();follow.reset([1,0,1]);follow.controller.yaw=35;follow.controller.distance=12;
 objects.get(world.localObjectId).wrapper.position.set(3,2,4);follow.update(world,{objects},camera,controls);assert.ok(controls.target.distanceTo(new Vector3(3,3,4))<.001);assert.ok(Math.abs(camera.position.distanceTo(controls.target)-12)<.00001);
 world.localObjectId=0x80000002;follow.update(world,{objects},camera,controls);assert.ok(controls.target.distanceTo(new Vector3(5,1,6))<.001);assert.equal(follow.controlledId,world.localObjectId);assert.equal(follow.controller.yaw,35);
 controls.target.x-=3;camera.position.x-=3;follow.update(world,{objects},camera,controls);assert.ok(controls.target.distanceTo(new Vector3(5,1,6))<.001,'OrbitControls cannot displace the native follow target');assert.equal(follow.controller.distance,12);
});
test('frame fractions retain native elapsed milliseconds and movement events do not alter server ownership',()=>{
 const object={id:0xffffffff,objectType:5,replicated:{position:[1,2,0],animation:4,walkRate:2200,runRate:4400}},a=new NetworkMotion(),b=new NetworkMotion();for(const m of [a,b]){m.ensure(object);m.observe(object,{path:[[100,2]],field8F4:1,field8EC:1});}for(let i=0;i<30;i++)a.update(1/30);for(let i=0;i<120;i++)b.update(1/120);assert.ok(Math.abs(a.pose(object.id).position[0]-b.pose(object.id).position[0])<.0001);
 const world=new NetworkWorld();world.registry.addObjectAtPos(object.id,structuredClone(object));world.apply({kind:'object-updates',records:[{action:'update',objectType:5,id:object.id,state:{position:[2,2,0],animation:4,path:[[100,2]],actionFlag:0}}]});assert.deepEqual(world.presentationChanges[0].changes.path,[[100,2]]);assert.equal(world.presentationChanges[0].action,'movement');world.presentationChanges[0].changes.path[0][0]=500;assert.equal(world.registry.get(object.id).replicated.path[0][0],100);assert.equal(world.localObjectId,0x7f000000);
});
test('scene movement follows only received paths and never mutates canonical positions or manufactures requests',()=>{
 const object={id:0xfffffff8,replicated:{position:[1,2,0],animation:4,walkRate:2200,runRate:4400}},motion=new NetworkMotion();motion.ensure(object);motion.observe(object,{animation:4,path:[[5,2]],field8F4:0});const before=structuredClone(object);motion.update(.1);const first=motion.pose(object.id);assert.ok(first.position[0]>1&&first.position[0]<5);motion.update(.1);assert.ok(motion.pose(object.id).position[0]>first.position[0]);assert.deepEqual(object,before);
 motion.observe(object,{animation:0,path:[],position:[2,2,0]});for(let i=0;i<10;i++)motion.update(.1);assert.deepEqual(motion.pose(object.id).position,[2,0,-2]);assert.deepEqual(object,before);
});
test('actual concurrent original-client wire capture moves render bindings between packets and preserves camera offset',async()=>{
 const root='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,root+'/data/nwm/Prelude.nwm'),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),issues=[],scene=new NetworkScene({world,resolver,report:(...d)=>issues.push(d),loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose:()=>{}}),releaseAsset:()=>{}}),report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v65.json',import.meta.url))),camera={position:new Vector3(14,12.8,5)},controls={target:new Vector3(6,.8,-3)},follow=new NetworkPlayerCamera();follow.reset([6,0,-3]);let between=0,maxShift=0;
 try{for(const hex of report.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);if(message.kind==='client-area')await scene.loadArea(message.area);else if(message.kind==='object-updates'&&scene.area){await scene.receiveMovementChanges(world.presentationChanges);await scene.sync();const remote=world.registry.get(0xfffffff8),before=remote?structuredClone(remote):null;
   for(let i=0;i<5;i++){const binding=scene.objects.get(0xfffffff8),old=binding?.wrapper.position.clone();scene.update(1/60);camera.quaternion??=new PerspectiveCamera().quaternion;follow.update(world,scene,camera,controls);if(old){const shift=old.distanceTo(binding.wrapper.position);if(shift>0){between++;if(shift>=4){assert.equal(scene.motion.objects.get(0xfffffff8).correction,0,'Native four-metre correction snaps finish immediately');}else maxShift=Math.max(maxShift,shift);}}if(follow.controlledId!==null)assert.ok(Math.abs(camera.position.distanceTo(controls.target)-20)<.0001);}if(remote)assert.deepEqual(remote,before,'renderer must not move canonical server proxies');
  }}assert.ok(between>20);assert.ok(maxShift>0&&maxShift<.2);assert.equal(follow.controlledId,world.localObjectId);assert.equal(issues.some(e=>e[0]==='network.scene-movement-unavailable'),false);
 }finally{await scene.dispose();}
});
