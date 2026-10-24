import test from 'node:test';import assert from 'node:assert/strict';import {Group,Mesh,BoxGeometry,MeshLambertMaterial,PerspectiveCamera,Material} from 'three';
import {TargetPreviewShader} from '../src/target_preview_shader.js';import {CameraKeyholePresentation} from '../src/camera_keyhole_shader.js';
test('target preview composes once when keyhole clones an already bound material and preview rebinds',()=>{
 for(const order of ['target-first','keyhole-first']){
  const root=new Group(),tile=new Group(),original=new MeshLambertMaterial(),mesh=new Mesh(new BoxGeometry(),original);tile.userData.nativeStaticTile=true;mesh.userData.nativeModelMesh=true;root.add(tile);tile.add(mesh);
  const preview=new TargetPreviewShader();preview.shader={cacheKey:'test-target',fragment:'varying vec3 nwnTarget_vPosWorld; void nwnTarget_ApplyTargetGroundHighlighting(inout vec4 c) {}'};
  const keyhole=new CameraKeyholePresentation({camera:new PerspectiveCamera(),renderer:{}});keyhole.shader={cacheKey:'test-keyhole',vertex:'void nwnKeyhole_SetupKeyholeFactors() {}',fragment:'void nwnKeyhole_ApplyKeyhole(inout vec4 c) {}'};
  if(order==='target-first')preview.bind(root);keyhole.bind(root);const inheritedCompile=mesh.material.onBeforeCompile;preview.bind(root);if(order==='target-first')assert.equal(mesh.material.onBeforeCompile,inheritedCompile);
  try{for(let n=0;n<3;n++){const shader={uniforms:{},vertexShader:'void main() {\n#include <project_vertex>\n}',fragmentShader:'void main() {\n#include <opaque_fragment>\n}'};mesh.material.onBeforeCompile(shader,{});assert.equal(shader.vertexShader.split('varying vec3 nwnTarget_vPosWorld;').length-1,1);assert.equal(shader.vertexShader.split('vec4 nwnTarget_world =').length-1,1);assert.equal(shader.fragmentShader.split('void nwnTarget_ApplyTargetGroundHighlighting').length-1,1);assert.equal(shader.uniforms.nwnTarget_targetObjectType,preview.uniforms.targetObjectType);assert.equal(mesh.material.customProgramCacheKey().split('|native-target-v1|test-target').length-1,1);preview.bind(root);}}
  finally{preview.dispose();keyhole.dispose();mesh.geometry.dispose();original.dispose();}assert.equal(mesh.material,original);assert.equal(original.onBeforeCompile,Material.prototype.onBeforeCompile);
 }
});
