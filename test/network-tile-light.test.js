import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {Group} from 'three';
import {createModelLight} from '../src/model_light.js';
import {applyTileMainLights,tileMainLightColors} from '../src/tile_lighting.js';
import {ModelAnimator} from '../src/model_animation.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-tile-light-observations.json',import.meta.url))),f=Math.fround;
const rgb=row=>[row/255,(255-row)/255,(row%3)/2].map(f),table={columns:['RED','GREEN','BLUE'],orderedRows:Array.from({length:256},(_,i)=>Object.fromEntries(['RED','GREEN','BLUE'].map((c,j)=>[c,String(rgb(i)[j])]))),defaultValue:'0'};

function fixture(prefix,names,colors){const root=new Group(),lights=[];for(const [i,name]of names.entries()){const group=new Group();group.userData.mdlNode=name;const light=createModelLight({name,properties:{color:colors?.[i]??[-1,-1,-1],radius:17,shadowradius:19,shadow:7,affectdynamic:7,lightpriority:7}});group.add(light);root.add(group);lights.push(light);}return{root,lights};}

test('40 original tile-part matches preserve native name suffix, case, truncation and absent-light behavior',()=>{
 assert.equal(oracle.matching.length,40);assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of oracle.matching){const instance=fixture(row.prefix,[row.node]);if(!row.cast)instance.lights[0].removeFromParent();const result=applyTileMainLights(instance,row.prefix,[rgb(0),rgb(1)]);assert.deepEqual(result.map(v=>v.present),row.slots.slice(0,2));}
});

test('320 complete original palette/apply/scene executions agree on BYTE rows, six named reads, missing anchors and conditional updates',()=>{
 assert.equal(oracle.updates.length,320);
 assert.equal(oracle.loader.resource,'LightColor');assert.ok(oracle.loader.assembly.some(x=>x.address==='0x1402b536c'&&x.text==='mov qword ptr [rbx + 0x1b8], rax'));
 for(const row of oracle.updates){const c=row.case,colors=tileMainLightColors([c.first,c.second],table),instance=fixture('tile',['tileml1','tileML2'],[0,1].map(i=>c.equal&(1<<i)?rgb([c.first,c.second][i]&255):[-1,-1,-1]));
  for(let i=0;i<2;i++)if(!(c.present&(1<<i)))instance.lights[i].removeFromParent();
  const result=applyTileMainLights(instance,'tile',colors);assert.deepEqual(row.indices,[c.first&255,c.second&255]);assert.deepEqual(row.reads,[c.first&255,c.second&255].flatMap(row=>['RED','GREEN','BLUE'].map(column=>({row,column}))));
  assert.deepEqual(result.flatMap((v,i)=>v.changed?[i]:[]),row.invalidated);
  for(let i=0;i<2;i++)if(result[i].present){const state=row.lights[i],v=result[i];assert.deepEqual(v.color,state.color);assert.equal(v.radius,state.radius);assert.equal(v.shadowRadius,state.shadowRadius);assert.equal(v.shadow,state.field78);assert.equal(v.affectDynamic,state.field88);assert.equal(v.priority,state.priority);}
 }
});

test('tile palette changes are instance-local, consume authored multiplier and survive animation baseline resets',()=>{
 const root=new Group(),group=new Group(),node={name:'tileml1',parent:'NULL',type:'light',position:[0,0,0],orientation:[0,0,0,1],scale:1};group.userData={mdlNode:node.name,mdlModel:'tile',mdlNodeIndex:0};const light=createModelLight({...node,properties:{color:[.1,.2,.3],radius:14,multiplier:2,ambientonly:0}});group.add(light);root.add(group);const model={modelName:'tile',nodes:[node],animations:[]},animator=new ModelAnimator(model,root),instance={root,animator};
 const separate=fixture('tile',['tileml1'],[[.1,.2,.3]]);let configured=0;applyTileMainLights(instance,'tile',[[.5,.6,.7],[0,0,0]],light=>{assert.equal(light.distance,10);configured++;});animator.reset();assert.equal(configured,1);assert.deepEqual(light.userData.mdlLight.color,[.5,.6,.7].map(f));assert.equal(light.userData.mdlLight.multiplier,1);assert.equal(light.userData.mdlLight.radius,10);assert.equal(light.castShadow,true);assert.equal(node.properties,undefined);assert.deepEqual(separate.lights[0].userData.mdlLight.color,[.1,.2,.3]);
});

test('real vanilla-server renderer applies active tile palettes, preserves equal-color radii and diagnoses source flames',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v29.json',import.meta.url))),diagnostics=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v29-diagnostics.json',import.meta.url)));
 assert.equal(report.failure,undefined);assert.equal(report.sampleFailure,undefined);assert.equal(report.renderer.state.phase,'playing');const tiles=report.renderer.scene.tileLighting;assert.equal(tiles.length,9);assert.equal(tiles.reduce((n,t)=>n+t.lights.filter(l=>l.changed).length,0),14);
 assert.deepEqual(tiles[0].lights[0].color,[1,.75,f(.3)]);assert.equal(tiles[0].lights[0].radius,10);assert.deepEqual(tiles[1].lights[0].color,[1.3,1.92,1.82].map(f));assert.equal(tiles[2].lights[0].changed,false);assert.equal(tiles[2].lights[0].radius,14);assert.deepEqual(report.renderer.scene.failedObjects,[]);assert.equal(diagnostics.some(d=>d.severity==='error'),false);assert.equal(diagnostics.filter(d=>d.code==='network.scene-tile-flames-unhandled').length,1);
});
