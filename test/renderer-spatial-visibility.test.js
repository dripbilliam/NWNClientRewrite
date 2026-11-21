import test from 'node:test';
import assert from 'node:assert/strict';
import {BoxGeometry,BufferGeometry,Float32BufferAttribute,Frustum,Material,Mesh,MeshBasicMaterial,Plane,ShaderMaterial,Vector3,Scene,PerspectiveCamera,Matrix4} from 'three';
import {RendererSpatialVisibility,classifySpatialBounds} from '../src/renderer_spatial_visibility.js';
import {RendererScenePlan} from '../src/renderer_scene_plan.js';

const planes=()=>[
 new Plane(new Vector3(1,0,0),5),new Plane(new Vector3(-1,0,0),5),
 new Plane(new Vector3(0,1,0),5),new Plane(new Vector3(0,-1,0),5),
 new Plane(new Vector3(0,0,1),5),new Plane(new Vector3(0,0,-1),5),
];
const view=()=>new Frustum(...planes());
function mesh(x=0,y=0,z=0){const m=new Mesh(new BoxGeometry(1,1,1),new MeshBasicMaterial());m.position.set(x,y,z);m.updateMatrixWorld();return m;}
// Independent corner enumeration: strict rejection only if every corner is
// outside one plane. Tests hierarchy equivalence, not original binary speed.
function reference(m,frustum){
 const p=m.geometry.attributes.position;const points=[];
 for(let i=0;i<p.count;i++)points.push(new Vector3().fromBufferAttribute(p,i).applyMatrix4(m.matrixWorld));
 return !frustum.planes.some(plane=>points.every(point=>plane.distanceToPoint(point)<-1e-5));
}
test('strict outside rejects; touching and crossing plane survive',()=>{
 const p=[new Plane(new Vector3(1,0,0),0)];
 assert.equal(classifySpatialBounds([-2,-1,-1,-1,1,1],p,1),-1);
 assert.notEqual(classifySpatialBounds([-1,-1,-1,0,1,1],p,1),-1);
 assert.notEqual(classifySpatialBounds([-1,-1,-1,1,1,1],p,1),-1);
 assert.equal(classifySpatialBounds([1,-1,-1,2,1,1],p,1),0);
});
test('contained nodes clear all plane bits, uncertain boundaries retain them',()=>{
 assert.equal(classifySpatialBounds([-1,-1,-1,1,1,1],planes()),0);
 assert.notEqual(classifySpatialBounds([-5,-1,-1,1,1,1],planes()),0);
});
test('hierarchical admission matches independent vertex oracle for transformed boxes',()=>{
 let seed=1977;const random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/2**32);
 const objects=Array.from({length:320},()=>{const m=mesh(random()*40-20,random()*40-20,random()*40-20);m.rotation.set(random()*6,random()*6,random()*6);m.scale.set((random()+.1)*(random()<.5?-1:1),random()*3+.1,random()*3+.1);m.updateMatrixWorld();return m;});
 const v=new RendererSpatialVisibility(),f=view();v.prepare(objects,f);
 // An AABB can admit a rotated box whose actual vertices are all outside;
 // it must never reject actual visible geometry. Three retains final culling.
 for(const m of objects)if(reference(m,f))assert.equal(v.accepts(m),true);
 assert.ok(v.snapshot().rejectedNodes>0);
 assert.ok(v.snapshot().planeTests<objects.length*6);
});
test('static bounds are reused; object motion refits both ancestors and admission',()=>{
 const a=mesh(0),b=mesh(50),v=new RendererSpatialVisibility(),f=view();
 v.prepare([a,b],f);assert.equal(v.accepts(a),true);assert.equal(v.accepts(b),false);
 v.prepare([a,b],f);assert.equal(v.snapshot().updatedBounds,0);assert.equal(v.snapshot().rebuilds,0);
 a.position.x=60;b.position.x=0;a.updateMatrixWorld();b.updateMatrixWorld();
 v.prepare([a,b],f);assert.equal(v.accepts(a),false);assert.equal(v.accepts(b),true);assert.equal(v.snapshot().updatedBounds,2);
});
test('in-place vertex mutation, replaced channel and geometry invalidate bounds',()=>{
 const a=mesh(50),v=new RendererSpatialVisibility(),f=view();v.prepare([a],f);assert.equal(v.accepts(a),false);
 const p=a.geometry.attributes.position;for(let i=0;i<p.count;i++)p.setX(i,p.getX(i)-50);p.needsUpdate=true;
 v.prepare([a],f);assert.equal(v.accepts(a),true);
 a.geometry.setAttribute('position',new Float32BufferAttribute([0,0,0,1,0,0,0,1,0],3));
 v.prepare([a],f);assert.equal(v.accepts(a),false);
 a.geometry=new BoxGeometry();a.position.x=0;a.updateMatrixWorld();v.prepare([a],f);assert.equal(v.accepts(a),true);
});
test('membership removal, replacement, reordering and reset release source owners',()=>{
 const a=mesh(),b=mesh(50),c=mesh(),v=new RendererSpatialVisibility(),f=view();
 v.prepare([a,b],f);v.prepare([b,c],f);assert.equal(v.records.has(a),false);assert.equal(v.accepts(c),true);
 v.prepare([c,b],f);assert.equal(v.snapshot().rebuilds,1);assert.equal(v.accepts(b),false);
 v.reset();assert.equal(v.records.size,0);assert.equal(v.root,null);
});
test('camera rotation/plane change is evaluated even without object movement',()=>{
 const a=mesh(),v=new RendererSpatialVisibility(),f=view();v.prepare([a],f);assert.equal(v.accepts(a),true);
 for(const p of f.planes)p.constant=-100;v.prepare([a],f);
 assert.equal(v.snapshot().updatedBounds,0);assert.equal(v.accepts(a),false);
});
test('unsupported geometry/materials and disabled culling always keep ordinary path',()=>{
 const objects=[mesh(50),mesh(50),mesh(50),mesh(50),mesh(50)];
 objects[0].frustumCulled=false;objects[1].material=new ShaderMaterial();objects[2].isInstancedMesh=true;
 objects[3].material.onBeforeCompile=()=>{};objects[4].geometry=new BufferGeometry();
 const v=new RendererSpatialVisibility();v.prepare(objects,view());for(const o of objects)assert.equal(v.accepts(o),true);
 assert.equal(v.snapshot().fallback,objects.length);
 objects[0].frustumCulled=true;v.prepare(objects,view());assert.equal(v.accepts(objects[0]),false);
});
test('changing shader eligibility invalidates the indexed/fallback boundary',()=>{
 const a=mesh(50),v=new RendererSpatialVisibility(),f=view();v.prepare([a],f);assert.equal(v.accepts(a),false);
 a.material.onBeforeCompile=()=>{};v.prepare([a],f);assert.equal(v.accepts(a),true);
 a.material.onBeforeCompile=Material.prototype.onBeforeCompile;v.prepare([a],f);assert.equal(v.accepts(a),false);
});
test('empty membership and non-finite geometry are conservative and cleanly recover',()=>{
 const v=new RendererSpatialVisibility(),a=mesh(50);a.geometry.attributes.position.setX(0,NaN);a.geometry.attributes.position.needsUpdate=true;
 v.prepare([a],view());assert.equal(v.accepts(a),true);
 a.geometry=new BoxGeometry();v.prepare([a],view());assert.equal(v.accepts(a),false);
 v.prepare([],view());assert.equal(v.records.size,0);assert.equal(v.root,null);
});
test('refitting changed leaves preserves visibility across multiple hierarchy levels',()=>{
 const objects=Array.from({length:120},(_,i)=>mesh(i*5)),v=new RendererSpatialVisibility(),f=view();v.prepare(objects,f);
 for(let i=0;i<objects.length;i++){objects[i].position.x=501-i*5;objects[i].updateMatrixWorld();}
 v.prepare(objects,f);for(const o of objects)assert.equal(v.accepts(o),reference(o,f));
 assert.equal(v.snapshot().rebuilds,0);assert.equal(v.snapshot().updatedBounds,120);
});
test('scene-plan handoff preserves render membership/order and releases the index',()=>{
 const previous=()=>false,renderer={nwnDrawAPI:{projectionVersion:1,project:previous},domElement:{addEventListener(){},removeEventListener(){}},xr:{enabled:false},sortObjects:false};
 const plan=new RendererScenePlan(renderer),scene=new Scene(),camera=new PerspectiveCamera(),objects=[mesh(),mesh(50),mesh(1)];scene.add(...objects);
 const run=spatial=>{plan.enabled=true;plan.spatialEnabled=spatial;plan.prepareMembership(objects,{scene,camera});const draws=[];assert.equal(plan.project(scene,camera,{list:{push:o=>draws.push(o)},state:{},objects:{update:o=>o.geometry},frustum:view(),projection:new Matrix4(),vector:new Vector3()}),true);return draws;};
 const reference=run(false),candidate=run(true);assert.deepEqual(candidate,reference);assert.deepEqual(scene.children,objects);assert.ok(plan.snapshot().spatial.indexed>0);
 plan.dispose();assert.equal(renderer.nwnDrawAPI.project,previous);assert.equal(plan.spatial.records.size,0);
});
