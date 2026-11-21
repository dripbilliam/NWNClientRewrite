import test from 'node:test';
import assert from 'node:assert/strict';
import {Scene,Mesh,BoxGeometry,MeshBasicMaterial,DataTexture,RGBAFormat} from 'three';
import {ReplayDiscardCandidates} from '../performance-candidates/replay-discard-candidates.mjs';

test('discard replay restores alpha across modes and applies selection to replacement keyhole owners',()=>{
 const scene=new Scene(),texture=new DataTexture(new Uint8Array([255,255,255,255]),1,1,RGBAFormat),material=new MeshBasicMaterial({map:texture,alphaTest:.5});
 scene.add(new Mesh(new BoxGeometry(),material));
 const owner=()=>({bindings:new Map(),setInactivePrograms(value){this.enabled=value;},snapshot(){return{specializeInactive:this.enabled};}});
 let keyhole=owner();const candidate=new ReplayDiscardCandidates({properties:new Map()},()=>keyhole);
 candidate.select('native-discard');candidate.prepare(scene);assert.equal(material.alphaTest,0);assert.equal(keyhole.enabled,true);assert.equal(candidate.snapshot().opaqueAlpha.removed,1);
 keyhole=owner();candidate.prepare(scene);assert.equal(keyhole.enabled,true);
 candidate.select('keyhole-inactive');candidate.prepare(scene);assert.equal(material.alphaTest,.5);assert.equal(keyhole.enabled,true);
 candidate.select('opaque-alpha');candidate.prepare(scene);assert.equal(material.alphaTest,0);assert.equal(keyhole.enabled,false);
 candidate.select('baseline');candidate.prepare(scene);assert.equal(material.alphaTest,.5);assert.equal(keyhole.enabled,false);
 candidate.select('native-discard');candidate.prepare(scene);candidate.dispose();assert.equal(material.alphaTest,.5);assert.equal(keyhole.enabled,false);
 texture.dispose();material.dispose();scene.children[0].geometry.dispose();
});

test('discard diagnostics distinguish actual compiled keyhole variants from flags and unprepared materials',()=>{
 const materials=Array.from({length:4},()=>({})),properties=new Map(materials.slice(0,3).map((m,i)=>[m,{currentProgram:{cacheKey:['ordinary','native|can=0','native|can=1'][i]}}]));properties.set(materials[3],{});
 const owner={bindings:new Map([[{}, {states:materials.map(material=>({material}))}]]),snapshot:()=>({specializeInactive:true})};
 assert.deepEqual(new ReplayDiscardCandidates({properties},()=>owner).snapshot().programs,{inactive:1,active:1,ordinary:1,unprepared:1});
});
