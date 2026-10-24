import test from 'node:test';
import assert from 'node:assert/strict';
import {DataTexture,Mesh,BoxGeometry,MeshLambertMaterial,Scene} from 'three';
import {RendererOpaqueAlpha} from '../src/renderer_opaque_alpha.js';
const texture=(alpha=255)=>{const t=new DataTexture(new Uint8Array([100,120,140,alpha]),1,1);t.needsUpdate=true;return t;};
function fixture(alpha=255){const map=texture(alpha),material=new MeshLambertMaterial({map,alphaTest:.035}),mesh=new Mesh(new BoxGeometry(),material),scene=new Scene(),owner=new RendererOpaqueAlpha();scene.add(mesh);owner.enabled=true;return{owner,map,material,mesh,scene};}
test('proven opaque samples remove an ineffective cutoff, disable restores it',()=>{
 const f=fixture();f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,0);assert.equal(f.owner.snapshot().removed,1);
 f.owner.prepare(f.scene);assert.equal(f.owner.snapshot().scannedTextures,0);
 f.owner.enabled=false;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);assert.equal(f.owner.materials.size,0);
});
test('transparency, changed alpha data and opacity fades retain effective cutoff',()=>{
 const f=fixture();f.owner.prepare(f.scene);f.map.image.data[3]=0;f.map.needsUpdate=true;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);
 f.map.image.data[3]=255;f.map.needsUpdate=true;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,0);
 f.material.opacity=.01;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);
 f.material.opacity=1;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,0);
});
test('a transparent authored mip cannot be certified by an opaque base level',()=>{
 const f=fixture();f.map.mipmaps=[{data:new Uint8Array([0,0,0,0]),width:1,height:1}];f.map.needsUpdate=true;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);
});
test('unknown storage, alpha producers and draw callbacks stay ordinary',()=>{
 for(const mutate of [f=>f.map.isCompressedTexture=true,f=>f.map.image={width:1,height:1},f=>f.material.alphaMap=texture(),f=>f.material.vertexColors=true,f=>f.material.onBeforeCompile=()=>{},f=>f.mesh.onBeforeRender=()=>{},f=>f.material.onBeforeRender=()=>{},f=>f.map.onUpdate=()=>{}]){
  const f=fixture();mutate(f);f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);
 }
});
test('one unknown owner blocks optimization for a shared material regardless of traversal order',()=>{
 for(const reverse of [false,true]){const f=fixture(),other=new Mesh(new BoxGeometry(),f.material);other.onBeforeRender=()=>{};f.scene.add(other);if(reverse)f.scene.children.reverse();f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);}
});
test('detached materials restore and release, external cutoff changes are respected',()=>{
 const f=fixture();f.owner.prepare(f.scene);f.material.alphaTest=.6;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,0);
 f.scene.remove(f.mesh);f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.6);assert.equal(f.owner.materials.size,0);
});
test('cutoff equality and float-rounding boundaries retain original shader behavior',()=>{
 for(const opacity of [.035,.034999999,.0350000001]){const f=fixture();f.material.opacity=opacity;f.owner.prepare(f.scene);assert.equal(f.material.alphaTest,.035);}
});
test('disposal returns active materials to their source cutoff',()=>{const f=fixture();f.owner.prepare(f.scene);f.owner.dispose();assert.equal(f.material.alphaTest,.035);assert.equal(f.owner.enabled,false);});
