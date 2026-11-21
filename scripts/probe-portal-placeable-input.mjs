// Offline production scene + actual cached portal models. Derived facts only;
// no live server connection, movement, dialog click or asset-byte output.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';
import {Box3,Raycaster,Vector3} from 'three';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';import {ModelSourceCache} from '../src/model_source_cache.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';import {NetworkScene} from '../src/network_scene.js';import {NetworkWorld} from '../src/network_world.js';
import {networkDefaultInteraction,networkRadialActions} from '../src/network_action_menu.js';import {worldCursorId} from '../src/game_cursor.js';import {highlightEligible} from '../src/world_highlight.js';
const [install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={httpAttempts:0,models:[],issues:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});let cache;
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});assert.ok(result.ready);const resolver=await resources.openModule(null,result.resolved);cache=new ModelSourceCache(resolver);
 for(const name of ['plc_portal2','plc_d07']){
  const world=new NetworkWorld(),id=0x80000002,areaId=0x80000001,object={id,areaId,objectType:9,replicated:{name:{text:'Portal'},appearance:391,field264:1,position:[4,15.7,0],orientation:{yaw:0}}};world.areaId=areaId;world.registry.addObjectAtPos(id,object);
  const scene=new NetworkScene({world,resolver,loadAsset:async key=>({model:await cache.load(key)}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose(){}}),releaseAsset(){},report:(code,message,context)=>report.issues.push({code,message,context})});scene.area={id:areaId};scene.tables={placeables:{rows:new Map([[391,{ModelName:name}]])}};
  try{
   await scene.sync();const binding=scene.objects.get(id),hitMeshes=binding.models[0].placeableHitMeshes;assert.ok(hitMeshes.length);scene.root.updateWorldMatrix(true,true);const bounds=new Box3().setFromObject(hitMeshes[0]),center=bounds.getCenter(new Vector3()),ray=new Raycaster(new Vector3(center.x,bounds.max.y+10,center.z),new Vector3(0,-1,0));
   const hit=scene.pick(ray);assert.equal(hit.object.id,id);assert.equal(networkDefaultInteraction(hit.object),'object.use');assert.equal(worldCursorId(hit.object),25);assert.equal(highlightEligible(hit.object,{areaId}),true);assert.ok(networkRadialActions(hit.object,{id:4,objectType:5}).entries.some(e=>e.action==='placeable.use'&&!e.disabled));assert.ok(hitMeshes.every(mesh=>!mesh.material.visible&&!mesh.material.colorWrite));
   report.models.push({name,hitMeshes:hitMeshes.length,triangles:hitMeshes.reduce((sum,m)=>sum+m.geometry.attributes.position.count/3,0),objectType:hit.object.objectType,action:networkDefaultInteraction(hit.object),cursor:worldCursorId(hit.object),bounds:{min:bounds.min.toArray(),max:bounds.max.toArray()},invisible:true});
  }finally{await scene.dispose();assert.equal(scene.instances.size,0);}
 }
 report.success=true;
}catch(error){report.failure={name:error.name,message:error.message};process.exitCode=1;}finally{cache?.dispose();resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
