import test from 'node:test';
import assert from 'node:assert/strict';
import {Scene,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,PerspectiveCamera,Sphere,Vector3,DataTexture,RGBAFormat,Matrix4,Group,ShaderMaterial,Float32BufferAttribute,FrontSide,BackSide} from 'three';
import {RendererShadowInstances} from '../src/renderer_shadow_instances.js';
function fixture(){
 const buffers=new Set(),writes=[],sentinel={},gl={COPY_WRITE_BUFFER:1,COPY_WRITE_BUFFER_BINDING:2,DYNAMIC_DRAW:3,FLOAT:4,bound:sentinel,getParameter(n){assert.equal(n,2);return this.bound;},createBuffer(){const buffer={};buffers.add(buffer);return buffer;},bindBuffer(target,buffer){assert.equal(target,1);this.bound=buffer;},bufferData(target,length){assert.equal(target,1);this.bound.length=length;},bufferSubData(target,offset,data,begin,count){assert.equal(target,1);assert.equal(offset,0);assert.ok(count*4<=this.bound.length);writes.push({buffer:this.bound,data:[...data.slice(begin,begin+count)]});},isBuffer:b=>buffers.has(b),deleteBuffer(b){assert.ok(buffers.delete(b),'external buffer deleted twice');}},renderer={getContext:()=>gl},owner=new RendererShadowInstances(renderer),scene=new Scene();
 const map=(color=1)=>{const data=Uint8Array.from({length:64},(_,i)=>i%4===3?(i%12===3?0:255):color);return new DataTexture(data,4,4,RGBAFormat);};
 const mesh=(x=0,color=1)=>{const value=new Mesh(new BoxGeometry(),new MeshLambertMaterial({map:map(color),alphaTest:.035}));value.position.x=x;value.castShadow=true;scene.add(value);return value;};
 const entries=objects=>{scene.updateMatrixWorld(true);return objects.map(object=>({object,sphere:new Sphere(new Vector3().setFromMatrixPosition(object.matrixWorld),1)}));};
 const light=new PointLight();light.shadow.camera=new PerspectiveCamera(90,1,.1,100);light.shadow.camera.position.set(.1,2.3,8.7);light.shadow.camera.updateMatrixWorld(true);light.shadow.getFrustum=()=>({intersectsSphere:s=>s.center.x>=0});
 return{owner,gl,buffers,writes,sentinel,scene,map,mesh,entries,light};
}
test('equivalent geometry and full palette alpha bytes group while originals retain exact ownership and buffers retire once',()=>{
 const f=fixture(),a=f.mesh(0,10),b=f.mesh(2,40),parents=[a.parent,b.parent],geometries=[a.geometry,b.geometry],materials=[a.material,b.material],entries=f.entries([a,b]);let sourceDisposals=0;a.geometry.addEventListener('dispose',()=>sourceDisposals++);
 f.owner.begin(entries);const list=f.owner.list(entries,f.light);assert.equal(list.length,1);assert.equal(list[0].isInstancedMesh,true);assert.deepEqual([a.parent,b.parent],parents);assert.deepEqual([a.geometry,b.geometry],geometries);assert.deepEqual([a.material,b.material],materials);assert.equal(f.buffers.size,2);assert.equal(f.gl.bound,f.sentinel);assert.notEqual(list[0].geometry,a.geometry);
 const group=[...f.owner.groups.values()][0];assert.equal(list[0].boundingSphere.radius,Infinity);assert.equal(group.proxy.count,2);assert.equal(f.writes.length,2);assert.equal(f.gl.bound,f.sentinel);f.owner.reset();assert.equal(f.buffers.size,0);assert.equal(sourceDisposals,0);assert.equal(f.owner.snapshot().cachedGroups,0);assert.equal(f.owner.snapshot().geometryKeys,0);assert.equal(f.owner.snapshot().currentMembers,0);f.owner.dispose();
});

test('partial VBO allocation failure releases owned buffers and retains ordinary draws until a new owner/context',()=>{
 const f=fixture(),a=f.mesh(),b=f.mesh(2),entries=f.entries([a,b]),allocate=f.gl.createBuffer;let allocations=0;f.gl.createBuffer=()=>++allocations===2?null:allocate();f.owner.begin(entries);assert.deepEqual(f.owner.list(entries,f.light),[a,b]);assert.equal(f.buffers.size,0);assert.equal(f.gl.bound,f.sentinel);assert.equal(f.owner.snapshot().disabled,true);assert.equal(f.owner.snapshot().currentMembers,0);f.owner.begin(entries);assert.deepEqual(f.owner.list(entries,f.light),[a,b]);assert.equal(allocations,2);f.owner.reset();f.gl.createBuffer=allocate;f.owner.begin(entries);assert.equal(f.owner.list(entries,f.light).length,1);f.owner.dispose();assert.equal(f.buffers.size,0);
});

test('optional shadow storage renaming preserves handles, face matrices, zero-face behavior and binding ownership',()=>{
 const f=fixture(),entries=f.entries([f.mesh(1),f.mesh(2)]);f.owner.orphanUploads=true;f.owner.begin(entries);f.owner.list(entries,f.light);const group=[...f.owner.groups.values()][0],handles=[group.world.buffer,group.modelView.buffer],before=f.gl.bufferData;let allocations=0;
 f.gl.bufferData=function(target,size,usage){allocations++;assert.equal(size,group.capacity*64);return before.call(this,target,size,usage);};
 for(let i=0;i<6;i++){f.light.shadow.camera.position.x++;f.light.shadow.camera.updateMatrixWorld(true);void group.proxy.boundingSphere;assert.equal(f.writes.at(-2).buffer,handles[0]);assert.equal(f.writes.at(-1).buffer,handles[1]);assert.equal(f.gl.bound,f.sentinel);}
 assert.equal(allocations,12);assert.equal(f.buffers.size,2);f.light.shadow.getFrustum=()=>({intersectsSphere:()=>false});f.light.shadow.camera.position.x++;f.light.shadow.camera.updateMatrixWorld(true);void group.proxy.boundingSphere;assert.equal(allocations,12);f.owner.dispose();assert.equal(f.buffers.size,0);
});

test('lazy frames inspect only redrawn light casters, share keys across lights and retire skipped groups',()=>{
 const f=fixture(),entries=f.entries([f.mesh(),f.mesh(2),f.mesh(4)]);let checks=0;const key=f.owner.key.bind(f.owner);f.owner.key=object=>{checks++;return key(object);};
 f.owner.begin(entries,{lazy:true});assert.equal(checks,0);assert.equal(f.owner.list(entries.slice(0,2),f.light).length,1);assert.equal(checks,2);assert.equal(f.owner.list(entries.slice(1),f.light).length,1);assert.equal(checks,3);f.owner.end();assert.equal(f.buffers.size,2);
 f.owner.begin(entries,{lazy:true});f.owner.end();assert.equal(checks,3,'cached shadows scanned unused casters');assert.equal(f.buffers.size,0);assert.equal(f.owner.snapshot().currentMembers,0);f.owner.dispose();
});

test('secondary UV streams and effective shadow-side inversion cannot collapse unlike caster output',()=>{
 const f=fixture(),a=f.mesh(),b=f.mesh(2),uv=a.geometry.attributes.uv.array;a.geometry.setAttribute('uv1',new Float32BufferAttribute(uv.slice(),2));b.geometry.setAttribute('uv1',new Float32BufferAttribute(uv.slice(),2));f.entries([a,b]);assert.equal(f.owner.key(a),f.owner.key(b));b.geometry.attributes.uv1.array[0]=.123; // initial data, before its first GPU/version observation
 b.geometry=b.geometry.clone();assert.notEqual(f.owner.key(a),f.owner.key(b));b.geometry=a.geometry.clone();b.material.side=BackSide;b.material.shadowSide=null;a.material.side=FrontSide;a.material.shadowSide=BackSide;assert.notEqual(f.owner.key(a),f.owner.key(b));b.material.shadowSide=BackSide;assert.equal(f.owner.key(a),f.owner.key(b));b.boundingSphere=new Sphere();assert.equal(f.owner.key(b),null);f.owner.dispose();
});
test('every shadow face receives exact float32 world/model-view matrices and the original face-frustum membership',()=>{
 const f=fixture(),a=f.mesh(1),b=f.mesh(-4),entries=f.entries([a,b]);a.scale.set(1.3,.7,2.1);a.rotation.set(.1,.2,.3);f.scene.updateMatrixWorld(true);f.owner.begin(entries);f.owner.list(entries,f.light);const group=[...f.owner.groups.values()][0];
 for(let i=0;i<6;i++){const c=f.light.shadow.camera;c.position.set(.123+i*.4,2.321,8.789);c.rotation.set(i*.05,i*.6,0);c.updateMatrixWorld(true);void group.proxy.boundingSphere;assert.equal(group.proxy.count,1);assert.deepEqual(f.writes.at(-2).data,[...new Float32Array(a.matrixWorld.elements)]);assert.deepEqual(f.writes.at(-1).data,[...new Float32Array(new Matrix4().multiplyMatrices(c.matrixWorldInverse,a.matrixWorld).elements)]);const count=f.writes.length;void group.proxy.boundingSphere;assert.equal(f.writes.length,count,'same face uploaded twice');}
 assert.equal(f.writes.length,12);f.light.shadow.getFrustum=()=>({intersectsSphere:()=>false});f.light.shadow.camera.position.x++;f.light.shadow.camera.updateMatrixWorld(true);void group.proxy.boundingSphere;assert.equal(group.proxy.count,0);assert.equal(f.writes.length,12,'empty shadow face uploaded unused capacity');assert.equal(f.gl.bound,f.sentinel);f.owner.dispose();assert.equal(f.buffers.size,0);
});
test('alpha bytes, geometry versions, texture transforms, draw ranges and layer changes split current groups',()=>{
 const f=fixture(),a=f.mesh(),b=f.mesh(2,99);f.entries([a,b]);assert.equal(f.owner.key(a),f.owner.key(b));
 const same=()=>assert.equal(f.owner.key(a),f.owner.key(b)),different=()=>assert.notEqual(f.owner.key(a),f.owner.key(b));
  b.material.map.image.data[3]=255;b.material.map.needsUpdate=true;different();b.material.map.image.data[3]=0;b.material.map.needsUpdate=true;different();b.material.map=f.map(99);same();b.material.map.offset.x=.3;different();b.material.map.offset.x=0;same();
 b.geometry.attributes.position.setX(0,20);b.geometry.attributes.position.needsUpdate=true;different();b.geometry=a.geometry.clone();same();b.geometry.setDrawRange(0,3);different();b.geometry.setDrawRange(0,Infinity);same();b.layers.set(2);different();f.owner.dispose();
});
test('deformed/negative/custom producers stay on the original path; singleton and removed groups free owned resources',()=>{
 const f=fixture(),a=f.mesh(),b=f.mesh(2),variants=[()=>{b.userData.animationOwnedGeometry=true;},()=>{b.userData.animationOwnedGeometry=false;b.scale.x=-1;f.scene.updateMatrixWorld(true);},()=>{b.scale.x=1;f.scene.updateMatrixWorld(true);b.onBeforeShadow=()=>{};},()=>{b.onBeforeShadow=a.onBeforeShadow;b.customDepthMaterial={};},()=>{b.customDepthMaterial=undefined;b.material=new ShaderMaterial();},()=>{b.material=a.material;b.add(new Group());}];
 for(const change of variants){change();assert.equal(f.owner.key(b),null);}b.clear();const entries=f.entries([a,b]);f.owner.begin(entries);assert.equal(f.owner.list(entries,f.light).length,1);assert.equal(f.buffers.size,2);f.owner.begin(f.entries([a]));assert.equal(f.buffers.size,0);assert.deepEqual(f.owner.list(f.entries([a]),f.light),[a]);f.owner.dispose();
});
