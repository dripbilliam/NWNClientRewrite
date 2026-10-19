import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {Group,Mesh,BoxGeometry,MeshBasicMaterial,PerspectiveCamera,Vector3,Vector2} from 'three';
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
