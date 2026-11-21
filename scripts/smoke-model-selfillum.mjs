// Read installed resources in place. Retain numeric observations, never assets.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import * as THREE from 'three';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {modelMaterialOptions} from '../src/model_material.js';
const [install,modulePath]=process.argv.slice(2);assert.ok(install&&modulePath,'Expected installed game and module paths');
const resolver=await openLocalModule(install,modulePath),model=parseModel(await resolver.getResource('vim_spike',2002));
const {root,nodeGroups}=createModelHierarchy(model),materials=[];
for(const node of model.nodes.filter(n=>n.type==='trimesh')){const material=new THREE.MeshLambertMaterial({...modelMaterialOptions(node),emissive:new THREE.Color().setRGB(...(node.selfillumcolor??[0,0,0]),THREE.SRGBColorSpace)});materials.push(material);nodeGroups.get(node).add(new THREE.Mesh(new THREE.BufferGeometry(),material));}
const animator=new ModelAnimator(model,root);assert.ok(animator.playNative('impact',{flags:3}));
let steps=0,observed=0;const states=[];
for(let frame=0;frame<150;frame++){
 animator.update(1/60);steps++;
 const glowing=model.nodes.filter(n=>n.nativeNode.controllers78.some(c=>c.displacement0===128&&(c.columnsA&15)===3));assert.equal(glowing.length,42);
 for(const node of glowing){const object=nodeGroups.get(node),part=animator.nativePose.byObject.get(object),color=animator.nativePose.read(part,128,3),expected=new THREE.Color().setRGB(...color,THREE.SRGBColorSpace);assert.ok(color.every(Number.isFinite));for(const mesh of object.children.filter(o=>o.isMesh))assert.deepEqual(mesh.material.emissive,expected);observed++;}
 if([0,60,120,149].includes(frame)){const n=glowing[0],o=nodeGroups.get(n);states.push({frame,time:animator.time,color:animator.nativePose.read(animator.nativePose.byObject.get(o),128,3),opacity:o.children[0].material.opacity,playing:animator.playing});}
}
assert.equal(animator.playing,false);assert.equal(model.unsupportedAnimations.length,0);
root.traverse(o=>{o.geometry?.dispose();for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])m.dispose();});materials.forEach(m=>m.dispose());
const report={model:model.modelName,nodes:model.nodes.length,glowingMeshCount:42,steps,observed,states,scope:'Installed binary resource, native Part/controller/run path and renderer material values. No real GPU pixels, sound or new live network-effect acceptance.'};
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');await fs.writeFile(path.join(workspace,'backups/animations/model-selfillum-installed-v1.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
