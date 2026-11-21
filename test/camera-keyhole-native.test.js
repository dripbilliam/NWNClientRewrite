import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Group,Mesh,BoxGeometry,MeshBasicMaterial,PerspectiveCamera,Vector3,Vector2,Box3} from 'three';
import {canKeyholeDissolve,keyholeBoxAbovePlane,keyholeCameraPlane} from '../src/camera_keyhole.js';
import {CameraKeyholePresentation,loadKeyholeShader} from '../src/camera_keyhole_shader.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-keyhole-observations.json',import.meta.url)));
test('original camera ownership, height and signed bbox-plane gates agree',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,756);
 for(const row of fixture.rows){assert.equal(canKeyholeDissolve(row.case),row.value,JSON.stringify(row.case));assert.equal(keyholeBoxAbovePlane(row.case.min,row.case.max,row.case.plane),row.distance);}
});
test('scene plane points forward through camera-to-player distance',()=>{
 assert.deepEqual(keyholeCameraPlane([0,-10,0],[0,1,0],[0,0,0]),[0,1,0,0]);
 assert.ok(keyholeBoxAbovePlane([-1,-5,0],[1,-4,4],[0,1,0,0])<0);
 assert.ok(keyholeBoxAbovePlane([-1,1,0],[1,2,4],[0,1,0,0])>0);
});
test('shared tile materials get independent flags, owned objects stay untouched, disposal restores originals',()=>{
 const root=new Group(),tile=new Group(),owned=new Group();tile.userData.nativeStaticTile=true;root.add(tile,owned);
 const material=new MeshBasicMaterial(),meshes=Array.from({length:3},()=>{const mesh=new Mesh(new BoxGeometry(2,4,2),material);mesh.userData.nativeModelMesh=true;return mesh;});tile.add(meshes[0],meshes[1]);owned.add(meshes[2]);meshes[0].position.z=4;meshes[1].position.z=-4;
 const camera=new PerspectiveCamera();camera.position.set(0,0,10);camera.lookAt(0,0,0);camera.updateMatrixWorld();root.updateMatrixWorld(true);
 const p=new CameraKeyholePresentation({camera,renderer:{getDrawingBufferSize:v=>v.set(256,256)}});p.shader={cacheKey:'test'};p.update(root,new Vector3(),{pitch:50,distance:10});
 for(const mesh of meshes)mesh.onBeforeRender();assert.equal(p.snapshot().eligible,1);assert.equal(p.bindings.size,2);assert.notEqual(meshes[0].material,meshes[1].material);assert.equal(meshes[2].material,material);
 p.dispose();for(const mesh of meshes)assert.equal(mesh.material,material);
});
test('installed shader loader rejects include cycles without writing assets',async()=>{
 await assert.rejects(loadKeyholeShader({getResource:async()=>new TextEncoder().encode('#include "inc_keyhole"')}),/include cycle/);
});

test('inactive program specialization omits keyhole code and follows eligibility changes',()=>{
 const root=new Group(),tile=new Group(),original=new MeshBasicMaterial(),mesh=new Mesh(new BoxGeometry(2,4,2),original);
 tile.userData.nativeStaticTile=true;mesh.userData.nativeModelMesh=true;root.add(tile);tile.add(mesh);mesh.position.z=-4;root.updateMatrixWorld(true);
 const camera=new PerspectiveCamera();camera.position.z=10;camera.lookAt(0,0,0);camera.updateMatrixWorld();
 const p=new CameraKeyholePresentation({camera,renderer:{getDrawingBufferSize:v=>v.set(256,256)}});
 p.shader={cacheKey:'test',vertex:'// keyhole declarations',fragment:'// keyhole discard'};p.update(root,new Vector3(),{pitch:50,distance:10});p.setInactivePrograms(true);
 const compile=()=>{const shader={uniforms:{},vertexShader:'#include <project_vertex>',fragmentShader:'#include <opaque_fragment>'};mesh.material.onBeforeCompile(shader,{});return shader;};
 mesh.onBeforeRender();assert.equal(p.snapshot().eligible,0);const plain=compile(),plainKey=mesh.material.customProgramCacheKey();assert.equal(plain.fragmentShader,'#include <opaque_fragment>');
 const version=mesh.material.version;mesh.onBeforeRender();assert.equal(mesh.material.version,version);
 mesh.position.z=4;root.updateMatrixWorld(true);mesh.onBeforeRender();assert.equal(p.snapshot().eligible,1);assert.ok(mesh.material.version>version);assert.notEqual(mesh.material.customProgramCacheKey(),plainKey);assert.ok(compile().fragmentShader.includes('ApplyKeyhole'));
 p.setInactivePrograms(false);mesh.position.z=-4;root.updateMatrixWorld(true);mesh.onBeforeRender();assert.ok(compile().fragmentShader.includes('ApplyKeyhole'));p.dispose();assert.equal(mesh.material,original);
});

test('keyhole membership refreshes on hierarchy edits and restores meshes moved outside static tiles',()=>{
 const root=new Group(),tile=new Group(),owned=new Group(),mesh=new Mesh(new BoxGeometry(),new MeshBasicMaterial());tile.userData.nativeStaticTile=true;mesh.userData.nativeModelMesh=true;root.add(tile,owned);tile.add(mesh);const original=mesh.material,p=new CameraKeyholePresentation({camera:new PerspectiveCamera(),renderer:{}});p.shader={cacheKey:'test'};p.bind(root);
 const traverse=root.traverse;let walks=0;root.traverse=function(...args){walks++;return traverse.apply(this,args);};p.bind(root);assert.equal(walks,0);
 let disposed=0;mesh.material.addEventListener('dispose',()=>disposed++);owned.add(mesh);p.bind(root);assert.equal(mesh.material,original);assert.equal(disposed,1);assert.equal(p.bindings.size,0);
 tile.add(mesh);p.bind(root);assert.equal(p.bindings.size,1);assert.notEqual(mesh.material,original);mesh.removeFromParent();p.bind(root);assert.equal(mesh.material,original);assert.equal(p.bindings.size,0);p.dispose();assert.equal(root._listeners?.childadded?.length??0,0);
});

test('leaf bounds match subtree queries through changing poses without updating ancestors per draw',()=>{
 const root=new Group(),tile=new Group(),mesh=new Mesh(new BoxGeometry(2,4,3),new MeshBasicMaterial());tile.userData.nativeStaticTile=true;mesh.userData.nativeModelMesh=true;root.add(tile);tile.add(mesh);
 const p=new CameraKeyholePresentation({camera:new PerspectiveCamera(),renderer:{}});p.shader={cacheKey:'test'};p.bind(root);p.enabled=true;p.plane=[.25,-.5,.75,-2];p.height=1;
 for(let i=0;i<40;i++){
  tile.position.set(i*.1,2,-3);tile.rotation.y=i*.17;mesh.rotation.x=i*.13;mesh.scale.set(i%2?-1:2,1.5,.5);root.updateMatrixWorld(true);
  const box=new Box3().setFromObject(mesh),min=[box.min.x,-box.max.z,box.min.y],max=[box.max.x,-box.min.z,box.max.y],expected=Number(canKeyholeDissolve({enabled:true,min,max,plane:p.plane,height:p.height}));
  const previous=mesh.updateWorldMatrix;mesh.updateWorldMatrix=()=>assert.fail('leaf draw redundantly updated world matrices');mesh.onBeforeRender();mesh.updateWorldMatrix=previous;assert.equal(p.bindings.get(mesh).can.value,expected);
 }
 const retired=[];let disposed=0;mesh.material.addEventListener('dispose',()=>disposed++);p.dispose({retire:fn=>retired.push(fn)});assert.equal(disposed,0);assert.equal(p.bindings.size,0);for(const fn of retired)fn();assert.equal(disposed,1);
});
test('desktop declaration adaptation namespaces attributes and preserves discard',async()=>{
 const source=`#if NO_DISCARD\n#define discard\n#endif
 attribute vec3 vNormal; uniform vec3 highp bboxMin;
 varying vec3 vPosView; varying float fFragCamOffset;
 uniform mat4 m_view_inv; uniform vec2 screenParams; uniform vec3 pixelParams;
 uniform int keyholeCanDissolve; uniform float cameraPitch; uniform float playerCameraDist;
 uniform vec3 playerPosition; uniform float keyholeDiameterMin; uniform float keyholeDiameterMax; uniform float keyholeMinZOffset;
 void ApplyKeyhole(inout vec4 color){discard;} void SetupKeyholeFactors(){}`;
 const result=await loadKeyholeShader({getResource:async()=>new TextEncoder().encode(source)});
 assert.match(result.vertex,/attribute vec3 nwnKeyhole_vNormal/);assert.match(result.vertex,/uniform highp vec3 nwnKeyhole_bboxMin/);assert.match(result.fragment,/{discard;}/);assert.doesNotMatch(result.fragment,/nwnKeyhole_discard/);
});
