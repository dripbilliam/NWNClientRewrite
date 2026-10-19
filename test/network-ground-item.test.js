import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeItemResourceRef,groundItemModelPlan,selectGroundItemModels} from '../src/item_model.js';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {modelMaterialOptions} from '../src/model_material.js';
import {networkDefaultInteraction,networkRadialActions} from '../src/network_action_menu.js';
import {Mesh,MeshBasicMaterial,BufferGeometry,Float32BufferAttribute,Raycaster,Vector3,Box3} from 'three';
import {Group} from 'three';
const load=n=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${n}.json`,import.meta.url))),fixture=load('native-network-item-model-observations');
const table=(columns,rows)=>({columns,orderedRows:rows,defaultValue:'****'});

test('252 original model/icon naming executions preserve hidden-return ABI, BMT parts, signed SHORTs and gender variants',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.names.length,252);
 for(const row of fixture.names){const c=row.case,schema={modelType:c.modelType,itemClass:c.prefix,genderSpecific:Boolean(c.variantFlag)};assert.equal(nativeItemResourceRef(schema,c.part,c.number,c.variant),row.model);assert.equal(nativeItemResourceRef(schema,c.part,c.number,c.variant,true),row.icon);}
});

test('512 complete original CreateItem executions agree on ground models, fallback probes, load selectors and armor thresholds',async()=>{
 assert.equal(fixture.construct.length,512);
 for(const row of fixture.construct){
  const c=row.case,baseRows=Array.from({length:81},()=>({ModelType:String(c.modelType),ItemClass:c.prefix,DefaultModel:c.defaultModel})),parts=Array.from({length:19},(_,i)=>[12,32,42][i%3]),plan=groundItemModelPlan({baseItem:c.baseId,parts,colors:[1,2,3,4,5,6]},{baseitems:table(['ModelType','ItemClass','DefaultModel'],baseRows),parts_chest:table(['ACBonus'],Array.from({length:43},()=>({ACBonus:String(c.ac)})))});
  const exists=name=>row.probes.find(v=>v.type===2002&&v.name===name)?.exists??false;
  let selected;try{selected=await selectGroundItemModels(plan,exists);}catch{assert.equal(row.success,false);assert.deepEqual(row.loads,[]);continue;}
  assert.deepEqual((c.bodyFailure?selected.slice(0,1):selected).map(v=>({model:v.name,selector:v.selector})),row.loads);assert.equal(row.success,!c.bodyFailure);assert.deepEqual(row.plays,row.success&&plan.defaultAnimation?['default']:[]);
  if(c.modelType===1||c.modelType===3)assert.deepEqual(plan.palette,[0,0,5,6,3,4,1,2,0,0]);
 }
});

function geometry(model){
 const {root,nodeGroups}=createModelHierarchy(model);
 for(const node of model.nodes){if(node.type!=='trimesh'||node.render===false||!node.faces.length)continue;const positions=[];for(const face of node.faces)for(const index of face.slice(0,3)){const v=node.verts[index];positions.push(v[0],v[2],-v[1]);}const g=new BufferGeometry();g.setAttribute('position',new Float32BufferAttribute(positions,3));nodeGroups.get(node).add(new Mesh(g,new MeshBasicMaterial(modelMaterialOptions(node))));}
 return root;
}

test('captured dropped item binds all three installed weapon components and removes the same render binding on pickup',async()=>{
 const install=path.resolve('../FullDecomp/NwnRootInstall'),res=installedNetworkResources({install}),resolver=await openLocalModule(install,await res.findFile('nwm','Prelude','nwm')),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),report=load('local-network-renderer-v25'),issues=[],models=[];
 let destroyed=0;const scene=new NetworkScene({world,resolver,report:(...d)=>issues.push(d),loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:(asset,name)=>{models.push(name);return{root:geometry(asset.model),dispose:()=>destroyed++};},releaseAsset:()=>{}});
 const id=report.itemActions[0].itemId;let canonical,picked=false,rendered=false;
 try{
  for(const hex of report.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);if(m.kind==='client-area')await scene.loadArea(m.area);else if(m.kind==='object-updates'&&scene.area)await scene.sync();if(!canonical&&world.registry.get(id))canonical=world.registry.get(id);if(canonical)assert.equal(world.registry.get(id),canonical);
   const binding=scene.objects.get(id);if(binding&&!rendered){rendered=true;assert.equal(binding.models.length,3);const names=binding.models.map(p=>p.root.name.toLowerCase());assert.deepEqual(names,['wswdg_b_012','wswdg_m_032','wswdg_t_042']);assert.equal(canonical.areaId,world.areaId);
    const box=new Box3().setFromObject(binding.wrapper),center=box.getCenter(new Vector3()),start=center.clone().add(new Vector3(0,5,0));const hit=scene.pick(new Raycaster(start,new Vector3(0,-1,0)));if(hit?.object?.id===id)picked=true;
   }
  }
  assert.equal(rendered,true);assert.equal(scene.objects.has(id),false);assert.equal(canonical.inventoryLocation.channel,'R');assert.equal(scene.snapshot().failedObjects.length,0);assert.equal(issues.some(d=>/ground-item-unhandled|scene-object-failed/.test(d[0])),false);
  assert.equal(picked,true,'The dropped item must be pickable in the full native starting room with front-face culling');
 }finally{await scene.dispose();assert.ok(destroyed>0);}
});

test('real renderer canvas picking sends native pickup for the rendered canonical item and returns it to inventory',()=>{
 const report=load('local-network-renderer-v28'),diagnostics=load('local-network-renderer-v28-diagnostics');assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.renderer.state.phase,'playing');assert.equal(report.itemActions.length,2);assert.equal(report.itemActions[1].step.mode,'worldclick');assert.equal(report.itemActions[1].result.worldclick,true);const id=report.itemActions[0].itemId;assert.equal(report.itemActions[1].itemId,id);
 const ground=report.samples.flatMap(s=>s.scene?.objects??[]).find(o=>o.id===id);assert.equal(ground.objectType,6);assert.equal(ground.models,3);assert.deepEqual(ground.resources.map(n=>n.toLowerCase()),['wswdg_b_012','wswdg_m_032','wswdg_t_042']);assert.ok(Number.isFinite(ground.screen.x)&&Number.isFinite(ground.screen.y));
 const results=report.wireMessages.map(h=>Buffer.from(h,'hex')).filter(p=>p[1]===12).map(p=>decodeServerGameMessage(p));assert.deepEqual(results.map(m=>[m.itemId,m.operation,m.success]),[[id,'drop',true],[id,'pickup',true]]);assert.equal(report.samples.at(-1).inventory.backpack.some(i=>i.id===id),true);assert.equal(report.renderer.scene.objects.some(o=>o.id===id),false);assert.deepEqual(report.renderer.scene.failedObjects,[]);
 assert.equal(diagnostics.some(d=>d.severity==='error'||/ground-item-unhandled|scene-object-failed|item-model-fallback|invalid|record-unhandled/.test(d.code)),false);
 const item={id,objectType:6,item:{name:{text:'server item'}}},actor={id:0xffffffff,objectType:5};assert.equal(networkDefaultInteraction(item),'item.pickup');assert.equal(networkRadialActions(item,actor).entries.find(e=>e.slot===4).action,'item.pickup');
});

test('a present corrupt item model fails without fallback and a later server appearance can recover its binding',async()=>{
 const id=0x80000002,areaId=0x80000001,world=new NetworkWorld();world.areaId=areaId;const baseitems=table(['ModelType','ItemClass','DefaultModel'],[{ModelType:'2',ItemClass:'weapon',DefaultModel:'it_bag'}]),calls=[],issues=[];
 const scene=new NetworkScene({world,resolver:{getResource:async()=>new Uint8Array(1)},report:(...d)=>issues.push(d),loadAsset:async name=>{calls.push(name);if(name==='weapon_b_001')throw new Error('Corrupt model');return{model:{modelName:name}};},instantiate:asset=>{const root=new Group();root.name=asset.model.modelName;return{root,dispose:()=>{}};},releaseAsset:()=>{}});scene.area={id:areaId};scene.tables={baseitems};
 const state=parts=>[{action:'create',id,objectType:6,state:{item:{baseItem:0,parts}}},{action:'update',id,objectType:6,state:{position:[0,0,0]}}];
 try{world.applyObjectUpdates(state([1,2,3]));await scene.sync();assert.deepEqual(calls,['weapon_b_001']);assert.deepEqual(scene.snapshot().failedObjects,[id]);assert.equal(scene.objects.has(id),false);world.applyObjectUpdates(state([4,2,3]));await scene.sync();assert.equal(scene.objects.get(id).models.length,3);assert.deepEqual(scene.snapshot().failedObjects,[]);assert.equal(calls.includes('it_bag'),false);}finally{await scene.dispose();}
});
