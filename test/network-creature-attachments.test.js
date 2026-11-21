import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeCreatureAttachments,relayCreatureAnimations,creatureAnimationSource,networkBindingAnimator} from '../src/network_creature_models.js';
import {parseAsciiMdl} from '../src/model_parser.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-attachments-v1.json',import.meta.url)));
test('native tail and wing admission, cloak hide rules and scopes match the original branches',()=>{
 for(const c of oracle.cases){
  const object={appearance:{appearance:0,fieldAA4:c.kind==='tail'?c.id:0,fieldAA8:c.kind==='wings'?c.id:0,equipment:c.cloak?[{slot:64,item:{parts:[c.cloak]}}]:[]}},tables={appearance:{rows:new Map()},tailmodel:{rows:new Map([[c.id,{MODEL:'custom_mount'}]])},wingmodel:{rows:new Map([[c.id,{MODEL:'custom_mount'}]])},cloakmodel:{rows:new Map([[c.cloak,{HIDETAIL:String(c.hide),HIDEWING:String(c.hide)}]])}};
  const before=structuredClone(object),parts=nativeCreatureAttachments(object,tables,[1,2,3]);assert.equal(parts.length,c.absent?0:1);if(parts.length){assert.equal(parts[0].model,c.model);assert.equal(parts[0].nativeVisualScope,c.scope);assert.equal(parts[0].node,c.kind==='tail'?'tail':'wings');assert.deepEqual(parts[0].paletteColors,[1,2,3]);}
  assert.deepEqual(object,before);
 }
});
test('followers share animation requests without sharing clocks or completion callbacks',()=>{
 const calls=[],source={play:(name)=>name!=='missing'},followers=[{play:(n,o)=>calls.push([0,n,o])},{play:(n,o)=>calls.push([1,n,o])}];const before=source.play,dispose=relayCreatureAnimations(source,followers);
 source.play('walk',{loop:true,onComplete:()=>{}});source.play('missing');assert.equal(calls.length,2);assert.ok(calls.every(c=>c[1]==='walk'&&c[2].loop&&c[2].onComplete===null));dispose();assert.equal(source.play,before);
});

test('clipless invisible creatures animate through their visible attachment while normal bodies retain control',()=>{
 const empty={model:{animations:[]}},body={model:{animations:[{name:'pause1'}]}},tail={model:{animations:[{name:'cpause1'}]}},wing={model:{animations:[{name:'cpause1'}]}};
 assert.equal(creatureAnimationSource(empty,[tail,wing]),tail);
 assert.equal(creatureAnimationSource(undefined,[tail]),tail);
 assert.equal(creatureAnimationSource(body,[tail,wing]),body);
 assert.equal(creatureAnimationSource(empty,[]),empty);
 assert.equal(networkBindingAnimator({animator:tail,models:[{animator:empty}]}),tail);
 assert.equal(networkBindingAnimator({models:[{animator:body}]}),body);
});
test('a missing optional attachment row preserves other attachments and reports the failure',()=>{
 const notes=[],object={appearance:{appearance:0,fieldAA4:77,fieldAA8:88,equipment:[]}},tables={appearance:{rows:new Map()},tailmodel:{rows:new Map()},wingmodel:{rows:new Map([[88,{MODEL:'server_wings'}]])}};
 const parts=nativeCreatureAttachments(object,tables,[],(...e)=>notes.push(e));assert.equal(notes.length,1);assert.equal(parts.length,1);assert.equal(parts[0].model,'server_wings');
});
test('ASCII dangling geometry enters the same triangle/material path as binary dangling geometry',()=>{
 const model=parseAsciiMdl(`newmodel chest
beginmodelgeom chest
node danglymesh plate
 parent NULL
 bitmap custom_chest
 verts 3
 0 0 0
 1 0 0
 0 1 0
 tverts 3
 0 0 0
 1 0 0
 0 1 0
 faces 1
 0 1 2 1 0 1 2 0
endnode
endmodelgeom chest`);
 assert.equal(model.nodes[0].type,'trimesh');assert.equal(model.nodes[0].faces.length,1);assert.equal(model.nodes[0].verts.length,3);assert.deepEqual(model.materialNames,['custom_chest']);assert.ok(model.nodes[0].unsupportedFeatures.includes('Dangly-mesh simulation'));
});
