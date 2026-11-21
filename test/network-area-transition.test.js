import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {Group} from 'three';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkScene} from '../src/network_scene.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {openLocalModule} from '../scripts/local-module.mjs';

test('real vanilla-server door transfer replaces the scene, retains the controlled ID and survives long load frames',async()=>{
 const install='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,install+'/data/nwm/Prelude.nwm'),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),parent=new Group(),issues=[],scenes=[];
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-progression-v106.json',import.meta.url)));
 let current,controlled,oldObjectIds,areas=[];
 const makeScene=()=>new NetworkScene({world,resolver,report:(...d)=>issues.push(d),loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose:()=>{}}),releaseAsset:()=>{}});
 try{
  for(const hex of capture.wireMessages){
   const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});
   if(message.kind==='client-area'&&current){controlled=world.registry.get(world.localObjectId);oldObjectIds=[...current.objects.keys()].filter(id=>id!==controlled.id);await current.dispose();assert.equal(current.root.parent,null);assert.equal(current.objects.size,0);}
   world.apply(message);
   if(message.kind==='client-area'){
    if(controlled){assert.equal(world.registry.get(world.localObjectId),controlled);assert.equal(controlled.areaId,message.area.id);assert.deepEqual(controlled.replicated.position,message.position);}
    current=makeScene();scenes.push(current);await current.loadArea(message.area);parent.add(current.root);areas.push(message.area.resRef);
    assert.equal(parent.children.length,1);assert.equal(current.snapshot().areaId,world.areaId);assert.equal(current.snapshot().attached,true);
   }else if(message.kind==='object-updates'&&current){
    await current.receiveMovementChanges(world.presentationChanges);await current.sync();current.receiveAnimationChanges(world.presentationChanges);
    const before=structuredClone(world.registry.get(world.localObjectId));
    // Includes the load stall that formerly threw outside the verified trig
    // range and prevented Three from scheduling the following render frame.
    current.update(25);current.update(1/60);assert.deepEqual(world.registry.get(world.localObjectId),before);
   }
  }
  assert.deepEqual(areas,['m0q1a','m0q1b']);assert.equal(current.tileCount,100);assert.ok(current.objects.has(world.localObjectId));
  for(const id of oldObjectIds)assert.equal(current.objects.has(id),false,'Old-area binding must be absent');
  assert.equal(issues.some(d=>d[0]==='network.scene-facing-unavailable'),false);assert.equal(parent.children[0],current.root);
 }finally{for(const scene of scenes)await scene.dispose();}
});
