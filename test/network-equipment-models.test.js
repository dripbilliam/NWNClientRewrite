import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeWeaponAttachments} from '../src/network_equipment_models.js';
import path from 'node:path';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-held-equipment-observations.json',import.meta.url)));

test('220 complete original SwitchWeaponEvent cases agree on native bone/scale/priority/clear requests without canonical mutations',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,220);
 assert.equal(oracle.staticAttachment.vtables.find(v=>v.name==='Parts adjusted base').table,'0x140e755e8');
 for(const row of oracle.cases){
  const c=row.case,object={id:0xffffffff,appearance:{appearance:42,equipment:[]}};
  if(c.right)object.appearance.equipment.push({slot:16,id:0x80000002,item:{baseItem:c.rightBase}});
  if(c.left)object.appearance.equipment.push({slot:32,id:0x80000003,item:{baseItem:c.leftBase}});
  const table={columns:['WEAPONSCALE'],orderedRows:c.appearance?Array.from({length:43},()=>({WEAPONSCALE:c.scaleFound?String(c.scale):'****'})):[],defaultValue:'0'},before=structuredClone(object);
  const commands=nativeWeaponAttachments(object,table,{localObjectId:c.local?object.id:0x80000100,hidden:e=>e.id===0x80000002?c.hiddenRight:c.hiddenLeft,modelAvailable:id=>id===0x80000002?!c.missingRightModel:!c.missingLeftModel});
  assert.deepEqual(commands.map(({priority,...command})=>command),row.attach);assert.deepEqual(commands.filter(v=>v.priority!==undefined).map(v=>({itemId:v.itemId,value:v.priority})),row.priority);assert.deepEqual(object,before);
 }
});

test('real native-server equip/unequip, shield forearm and left-hand bow renders retain their item IDs and follow movement',()=>{
 const reports=[30,31,32].map(n=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${n}.json`,import.meta.url))));
 for(const [index,r]of reports.entries()){
  assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.renderer.state.phase,'playing');assert.equal(r.moves.length,2);assert.deepEqual(r.renderer.scene.failedObjects,[]);
  const diagnostics=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${30+index}-diagnostics.json`,import.meta.url)));assert.equal(diagnostics.some(d=>d.severity==='error'||/equipment-model-failed|equipment-attachment-failed/.test(d.code)),false);
 }
 const results=r=>r.wireMessages.map(h=>Buffer.from(h,'hex')).filter(b=>b[1]===12).map(b=>decodeServerGameMessage(b));
 assert.deepEqual(results(reports[0]).map(r=>[r.operation,r.success]),[['equip',true],['unequip',true],['equip',true],['unequip',true]]);assert.deepEqual(reports[0].renderer.scene.objects.find(o=>o.id===0xffffffff).held,[]);
 const moving=reports[0].samples.map(s=>s.scene?.objects.find(o=>o.id===0xffffffff)).filter(o=>o?.held.length&&[2,3].includes(o.animation));assert.ok(moving.length>0);assert.ok(moving.every(o=>o.held[0].anchor==='rhand'&&o.held[0].resources.length===3));
 const shield=reports[1].renderer.scene.objects.find(o=>o.id===0xffffffff).held.find(h=>h.anchor==='lforearm'),shieldResults=results(reports[1]);assert.equal(shield.resources.length,1);assert.deepEqual(shieldResults.map(r=>[r.itemId,r.operation,r.success]),[[shield.itemId,'unequip',true],[shield.itemId,'equip',true]]);
 const bow=reports[2].renderer.scene.objects.find(o=>o.id===0xffffffff).held;assert.equal(bow.length,1);assert.equal(bow[0].anchor,'lhand');assert.equal(bow[0].right,0);assert.equal(bow[0].resources.length,3);
});

test('captured vanilla player equipment binds installed item components to the animated skeleton while keeping canonical items nonspatial',async()=>{
 const install=path.resolve('../FullDecomp/NwnRootInstall'),resources=installedNetworkResources({install}),resolver=await openLocalModule(install,await resources.findFile('nwm','Prelude','nwm')),rules=await loadNetworkObjectRules(resolver),world=new NetworkWorld(),report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v29.json',import.meta.url))),issues=[];
 const scene=new NetworkScene({world,resolver,report:(...d)=>issues.push(d),loadAsset:async(name,r)=>({model:parseModel(await r.getResource(name,2002))}),instantiate:asset=>({root:createModelHierarchy(asset.model).root,dispose:()=>{}}),releaseAsset:()=>{}});
 try{
  for(const hex of report.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);if(m.kind==='client-area')await scene.loadArea(m.area);else if(m.kind==='object-updates'&&scene.area)await scene.sync();}
  const held=scene.snapshot().objects.flatMap(o=>(o.held??[]).map(h=>({owner:o.id,...h})));assert.ok(held.length>0,JSON.stringify(issues.filter(d=>/equipment/.test(d[0]))));
  for(const h of held){const item=world.registry.get(h.itemId),owner=world.registry.get(h.owner);assert.equal(item.equipmentOwnerId,h.owner);assert.notEqual(item.areaId,world.areaId);assert.equal(owner.appearance.equipment.some(e=>e.id===h.itemId),true);assert.ok(h.resources.length>0);assert.equal(scene.objects.has(h.itemId),false);}
  assert.equal(issues.some(d=>/equipment-model-failed|equipment-attachment-failed/.test(d[0])),false);
  const h=held[0],binding=scene.objects.get(h.owner),old=binding.held[0].root.position.clone(),position=[...world.registry.get(h.owner).replicated.position];position[0]+=5;world.apply({kind:'object-updates',records:[{action:'update',objectType:5,id:h.owner,state:{position,animation:0,path:[]}}]});scene.receiveMovementChanges(world.presentationChanges);scene.update(0);assert.ok(Math.abs(binding.held[0].root.position.x-old.x-5)<1e-4);
  scene.remove(h.owner);assert.equal(scene.root.children.some(n=>n.userData.worldObjectId===h.owner),false);scene.update(0);
 }finally{await scene.dispose();assert.equal(scene.instances.size,0);}
});
