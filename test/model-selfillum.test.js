import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as THREE from 'three';
import {applyModelControllers} from '../src/model_controller_apply.js';
import {parseAsciiMdl} from '../src/model_parser.js';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';

test('native mesh self-illumination and opacity match the original mesh control owner independently of position scale',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-mesh-selfillum-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,75);
 const node={values88:[0,1,.2,.4,.8,.8,.4,.2,1,.25],controllerCount80:2,controllers78:[{displacement0:128,columnsA:3,valueIndex8:2,timeIndex6:0,rows4:2},{displacement0:168,columnsA:1,valueIndex8:8,timeIndex6:0,rows4:2}]};
 for(const row of oracle.rows){const fields=new Map([[128,[0,0,0]],[168,[1]]]);applyModelControllers(node,fields,-.25,row.time,row.weight,{read:(p,o)=>p.get(o),write:(p,o,v)=>p.set(o,v),positionScale:()=>row.scale,activeMotionRun:()=>null});assert.deepEqual(fields.get(128),row.color);assert.deepEqual(fields.get(168),[row.alpha]);}
});

test('decoded ASCII selfillumcolor animates instance materials and restores the authored color for an omitted track',()=>{
 const model=parseAsciiMdl('newmodel glow\nbeginmodelgeom glow\nnode trimesh mesh\nselfillumcolor 0.1 0.2 0.3\nendnode\nendmodelgeom glow\nnewanim lit glow\nlength 1\nnode trimesh mesh\nselfillumcolorkey 2\n0 0 0 0\n1 1 0.5 0.25\nendnode\ndoneanim lit glow\nnewanim rest glow\nlength 1\nnode trimesh mesh\nendnode\ndoneanim rest glow');
 assert.deepEqual(model.unsupportedAnimations,[]);assert.equal(model.animations[0].tracks[0].property,'selfillumcolor');
 const material=new THREE.MeshLambertMaterial({emissive:new THREE.Color().setRGB(.1,.2,.3,THREE.SRGBColorSpace)}),instances=[];
 for(let i=0;i<2;i++){const {root,nodeGroups}=createModelHierarchy(model),mesh=new THREE.Mesh(new THREE.BufferGeometry(),material);nodeGroups.get(model.nodes[0]).add(mesh);instances.push({root,mesh,animator:new ModelAnimator(model,root)});}
 const [a,b]=instances;a.animator.play('lit',{loop:false});a.animator.update(.5);
 assert.deepEqual(a.mesh.material.emissive,new THREE.Color().setRGB(.5,.25,.125,THREE.SRGBColorSpace));assert.deepEqual(b.mesh.material.emissive,material.emissive);assert.notEqual(a.mesh.material,material);
 a.animator.play('rest');assert.deepEqual(a.mesh.material.emissive,material.emissive);
 for(const i of instances){i.mesh.geometry.dispose();i.mesh.material.dispose();}material.dispose();
});

test('binary static mesh self-illumination is disk100, distinct from overlapping emitter and light channels',()=>{
 function fixture(flags){const buffer=new ArrayBuffer(2048),d=new DataView(buffer),b=new Uint8Array(buffer),u=(o,v)=>d.setUint32(o,v,true);u(4,2036);u(84,232);u(88,1);b.set(new TextEncoder().encode('glow'),20);const n=244;u(n+108,flags);u(n+84,1300);u(n+88,1);u(n+96,1400);u(n+100,4);u(1312,100);d.setUint16(1316,1,true);d.setUint16(1320,1,true);b[1322]=3;[0,.1,.2,.3].forEach((v,i)=>d.setFloat32(1412+i*4,v,true));return buffer;}
 assert.deepEqual(parseBinaryMdl(fixture(33)).nodes[0].selfillumcolor,[.1,.2,.3].map(Math.fround));
 assert.equal(parseBinaryMdl(fixture(5)).nodes[0].selfillumcolor,undefined);assert.equal(parseBinaryMdl(fixture(3)).nodes[0].selfillumcolor,undefined);
});
