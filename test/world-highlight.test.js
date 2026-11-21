import test from 'node:test';
import assert from 'node:assert/strict';
import {BoxGeometry,Group,Mesh,MeshLambertMaterial,Scene,Vector3} from 'three';
import {highlightEligible,highlightColor,highlightName,highlightDamageLevel} from '../src/world_highlight.js';
import {WorldHighlightRenderer} from '../src/world_highlight_renderer.js';
import {highlightCreatureDetails} from '../src/world_highlight_assets.js';

test('highlight discovery respects current replicated ownership and explicit usability',()=>{
 const context={areaId:4,playerId:10},actor={id:10,areaId:4,objectType:5};
 assert.equal(highlightEligible(actor,context),true);
 assert.equal(highlightEligible(actor,{...context,all:true}),true);
 for(const object of [{...actor,areaId:5},{...actor,replicationRemoved:true},{...actor,destroyed:true},{...actor,objectType:7},{...actor,objectType:4}])assert.equal(highlightEligible(object,context),false);
 assert.equal(highlightEligible({...actor,objectType:10},context),true);
 assert.equal(highlightEligible({...actor,objectType:6},context),true);
 assert.equal(highlightEligible({...actor,objectType:6,inventoryLocation:{channel:'R'}},context),false);
 const chest={...actor,objectType:9};assert.equal(highlightEligible(chest,context),false);
 assert.equal(highlightEligible({...chest,replicated:{field264:1}},context),true);
 assert.equal(highlightEligible({...chest,replicated:{field264:0},usable:true},context),false);
 assert.equal(highlightEligible({...chest,usable:true},context),true);
 assert.equal(highlightEligible({...chest,staticState:{appearance:1},usable:true},context),false);
 assert.equal(highlightColor({...actor,id:11,replicated:{reaction:2}},10),'#ff5555');
});

test('injury category retains the server byte and original native HP thresholds',()=>{
 assert.equal(highlightDamageLevel({replicated:{damageLevel:3,hitPoints:{current:100,maximum:100}}}),3);
 for(const [current,expected]of [[100,0],[95,0],[94,1],[75,1],[74,2],[50,2],[49,3],[25,3],[24,4],[1,4],[0,5],[-10,5]])assert.equal(highlightDamageLevel({replicated:{hitPoints:{current,maximum:100}}}),expected);
 assert.equal(highlightDamageLevel({replicated:{}}),null);assert.equal(highlightDamageLevel({replicated:{hitPoints:{current:1,maximum:0}}}),null);
});

test('labels use the current text resolver, preserving server names and escaping in the DOM owner',async()=>{
 const seen=[],resolve=async value=>{seen.push(value);return value?.text??(value?.strRef===42?'Custom name':'');};
 assert.equal(await highlightName({firstName:{text:'Nibs'},lastName:{strRef:42}},resolve),'Nibs Custom name');
 assert.equal(await highlightName('<literal name>',resolve),'<literal name>');
 assert.equal(seen.length,2);
});

test('injury names come from the active damagelevels table and text resolver with no cross-context cache',async()=>{
 let reads=0;const assets={resolver:{getResource:async name=>{assert.equal(name,'damagelevels');reads++;return new TextEncoder().encode('2DA V2.0\n\nLABEL STRING_REF\n0 UNINJURED 6409\n1 BARELY_INJURED 6410\n2 INJURED 6411\n');}}},tables={portraits:{rows:new Map()}},object={id:5,replicated:{damageLevel:2}};
 const context={assets,tables,resolve:async value=>value.strRef===6411?'Injured':''};
 const first=await highlightCreatureDetails(object,context),second=await highlightCreatureDetails(object,{...context,resolve:async()=> 'Server-specific injury'});
 assert.equal(first.condition,'Injured');assert.equal(first.level,2);assert.equal(second.condition,'Server-specific injury');assert.equal(reads,1);
 const other={resolver:{getResource:async()=>new TextEncoder().encode('2DA V2.0\n\nLABEL STRING_REF\n0 A 1\n1 B 2\n2 CUSTOM 9999\n')}};
 assert.equal((await highlightCreatureDetails(object,{...context,assets:other,resolve:async value=>String(value.strRef)})).condition,'9999');
});

test('one highlight batch follows attachments and geometry without changing source materials or picking',()=>{
 const scene=new Scene(),root=new Group(),body=new Mesh(new BoxGeometry(1,2,1),new MeshLambertMaterial({color:0x665544})),attachment=new Group(),hand=new Mesh(new BoxGeometry(.2,.7,.2),body.material);
 for(const mesh of [body,hand])mesh.userData.nativeModelMesh=true;
 root.add(body,attachment);attachment.add(hand);attachment.position.set(1,1,0);root.position.set(3,0,0);scene.add(root);
 const renderer=new WorldHighlightRenderer(scene),entry={root,meshes:[body,hand],color:'#79bdff'},original=body.material,version=original.version,color=original.color.clone();
 const empty={root,meshes:[],color:'#79bdff'};renderer.update([empty],0);assert.equal(renderer.parts,0);assert.equal(empty.bounds.isEmpty(),true);
 renderer.update([entry],0);assert.equal(renderer.parts,2);assert.equal(renderer.mesh.count,2);assert.equal(renderer.mesh.geometry.attributes.position.count,18);assert.equal(renderer.mesh.castShadow,false);assert.equal(renderer.mesh.material.depthWrite,false);
 assert.equal(body.material,original);assert.equal(hand.material,original);assert.deepEqual(original.color,color);assert.equal(original.version,version);
 const bounds=entry.bounds.clone(),matrix=renderer.mesh.instanceMatrix.array.slice(16,32);attachment.position.y+=2;renderer.update([entry],100);assert.ok(entry.bounds.max.y>bounds.max.y);assert.notDeepEqual(renderer.mesh.instanceMatrix.array.slice(16,32),matrix);
 body.visible=false;renderer.update([entry],200);assert.equal(renderer.parts,1);
 hand.material.opacity=0;renderer.update([entry],300);assert.equal(renderer.parts,0);
 renderer.mesh.raycast({},[]);renderer.clear();assert.equal(renderer.mesh.visible,false);
 let sourceDisposed=false;body.geometry.addEventListener('dispose',()=>sourceDisposed=true);renderer.dispose();assert.equal(sourceDisposed,false);assert.equal(root.parent,scene);assert.deepEqual(root.position,new Vector3(3,0,0));
});
