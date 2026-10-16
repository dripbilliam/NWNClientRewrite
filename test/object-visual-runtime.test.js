import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {EquipmentInventory} from '../src/equipment_inventory.js';
const data=fields=>parseGff(writeGff('UTP ',R(fields))).root;

test('all five concrete visual owners retain canonical identity and record unavailable presentation',async()=>{
 const s=new ModuleSession(null),o=s.register('placeable','visual-runtime',{authored:{},areaId:0x7f000000,deferTagLookup:true}),id=o.id,next=s.registry.nextObjectId[0],begin=runtimeDiagnostics.records.length;
 const source=data({VisTransformList:F(15,[R({Scope:F(5,0),ScaleX:F(8,1.5)}),R({Scope:F(5,3),TranslateZ:F(8,4)}),R({Scope:F(5,0),ScaleX:F(8,2)})]),
  Material:F(14,R({ShaderParams:F(15,[R({Type:F(0,1),Int:F(5,17),Material:F(10,'mesh'),Param:F(10,'param')})])})),
  TextureReplace:F(14,R({TextureReplaceLi:F(15,[R({OldTexture:F(11,'stone'),NewTexture:F(11,'wood')})])})),
  AnimationReplace:F(14,R({AnimationReplace:F(15,[])})),MiscVisuals:F(14,R({VisibleDistance:F(8,23),TextBubbleText:F(10,'bubble')})),
 });
 await s.objectVisuals.load(o,source);assert.equal(s.registry.get(id),o);assert.equal(s.registry.nextObjectId[0],next);assert.equal(o.areaId,0x7f000000);
 assert.deepEqual([...o.nativeVisualTransforms2b0.keys()],[0,3]);assert.equal(new DataView(o.nativeVisualTransforms2b0.get(0).buffer).getFloat32(4,true),2);
 assert.equal(o.nativeVisualPools[0x2b8].records.length,1);assert.equal(o.nativeVisualPools[0x2c8].records.length,1);assert.equal(o.nativeAnimationOverridesLoaded,1);
 assert.equal(o.nativeProjectileRange268,23);assert.equal(o.nativeMiscVisualFields[0x278],'bubble');
 const missing=runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='object.visual-presentation-unimplemented');assert.equal(missing.length,4);assert.ok(missing.every(r=>r.context.objectId===id));
 const old=o.nativeVisualTransforms2b0;await s.objectVisuals.loadOwner(o,data({}),0x140497bb0);assert.equal(o.nativeVisualTransforms2b0,old);
 await s.objectVisuals.loadOwner(o,data({VisTransformList:F(15,[])}),0x140497bb0);assert.equal(o.nativeVisualTransforms2b0,old);assert.equal(old.size,0);
 await assert.rejects(()=>s.objectVisuals.loadOwner(o,source,0x140000000),/visual data owner/);
 assert.ok(runtimeDiagnostics.records.slice(begin).some(r=>r.context.owner===0x140000000&&r.context.objectId===id));
 await s.lifecycle.destroy(o);assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);assert.equal(o.nativeVisualTransforms2b0,null);
});

test('canonical equipped items update independent hand maps and release them with their creature',async()=>{
 const s=new ModuleSession(null),creature=s.register('creature','visual-carrier',{authored:{},areaId:0x7f000000}),item=s.register('item','visual-item',{authored:{},areaId:0x7f000000});
 creature.nativeEquipment=new EquipmentInventory(message=>{throw new Error(message);});item.possessorId=creature.id;creature.nativeEquipment.put(16,item);
 const next=s.registry.nextObjectId[0];await s.objectVisuals.loadOwner(item,data({VisualTransform:F(14,R({ScaleX:F(8,3)}))}),0x140497bb0);
 const right=creature.nativeHandVisualMaps[0xab0];assert.equal(right.size,1);assert.equal(creature.nativeHandVisualMaps[0xac0].size,0);assert.notEqual(right,item.nativeVisualTransforms2b0);assert.notEqual(right.get(0),item.nativeVisualTransforms2b0.get(0));
 assert.equal(new DataView(right.get(0).buffer).getFloat32(4,true),3);
 creature.nativeEquipment.remove(item);creature.nativeEquipment.put(32,item);
 await s.objectVisuals.loadOwner(item,data({VisualTransform:F(14,R({ScaleX:F(8,5)}))}),0x140497bb0);
 const left=creature.nativeHandVisualMaps[0xac0];assert.equal(new DataView(left.get(0).buffer).getFloat32(4,true),5);assert.equal(new DataView(right.get(0).buffer).getFloat32(4,true),3);
 assert.equal(s.registry.get(item.id),item);assert.equal(item.possessorId,creature.id);assert.equal(s.registry.nextObjectId[0],next);
 await s.lifecycle.destroy(creature);assert.equal(s.registry.get(creature.id),undefined);assert.equal(s.registry.get(item.id),undefined);assert.equal(left.size,0);assert.equal(right.size,0);assert.equal(s.registry.nextObjectId[0],next);
});
