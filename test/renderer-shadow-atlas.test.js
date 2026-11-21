import test from 'node:test';import assert from 'node:assert/strict';
import {Scene,Mesh,BoxGeometry,SphereGeometry,MeshLambertMaterial,PointLight,PerspectiveCamera,Sphere,Vector3,Matrix4,Group,DoubleSide,FrontSide} from 'three';
import {RendererShadowAtlas} from '../src/renderer_shadow_atlas.js';
function fixture(options={}){
 const buffers=new Set(),writes=[],sentinel={},multiCalls=[],drawElements=()=>{},originalDraw=()=>{},gl={COPY_WRITE_BUFFER:1,COPY_WRITE_BUFFER_BINDING:2,DYNAMIC_DRAW:3,UNSIGNED_INT:4,ELEMENT_ARRAY_BUFFER:5,ELEMENT_ARRAY_BUFFER_BINDING:6,bound:sentinel,elementBound:sentinel,drawElements,getExtension:()=>({multiDrawElementsWEBGL:(...args)=>multiCalls.push(args)}),getParameter(n){return n===6?this.elementBound:this.bound;},createBuffer(){const b={};buffers.add(b);return b;},bindBuffer(t,b){if(t===5)this.elementBound=b;else this.bound=b;},bufferData(t,n){(t===5?this.elementBound:this.bound).bytes=n;},bufferSubData(_t,_o,data,start,count){writes.push([...data.subarray(start,start+count)]);},isBuffer:b=>buffers.has(b),deleteBuffer:b=>assert.equal(buffers.delete(b),true)};
 const renderer={getContext:()=>gl,capabilities:{maxTextureSize:4096},renderBufferDirect:originalDraw},owner=new RendererShadowAtlas(renderer,options),scene=new Scene(),a=new Mesh(new BoxGeometry(),new MeshLambertMaterial()),b=new Mesh(new SphereGeometry(1,7,4),new MeshLambertMaterial());a.castShadow=b.castShadow=true;a.position.x=2;b.position.x=-2;scene.add(a,b);scene.updateMatrixWorld(true);
 const entries=()=>[a,b].map(object=>({object,sphere:new Sphere(new Vector3().setFromMatrixPosition(object.matrixWorld),1)}));
 const light=new PointLight();light.shadow.camera=new PerspectiveCamera(90,1,.1,100);light.shadow.camera.position.set(0,3,8);light.shadow.camera.updateMatrixWorld(true);light.shadow.getFrustum=()=>({intersectsSphere:()=>true});
 return{gl,renderer,owner,scene,a,b,entries,light,buffers,writes,sentinel,multiCalls,originalDraw,drawElements};
}
test('different rigid geometries share a shadow atlas without changing source ownership; resources retire',()=>{
 const f=fixture(),e=f.entries(),sources=e.map(s=>({parent:s.object.parent,geometry:s.object.geometry,material:s.object.material}));let sourceDisposals=0;f.a.geometry.addEventListener('dispose',()=>sourceDisposals++);
 f.owner.begin(e);assert.notEqual(f.renderer.renderBufferDirect,f.originalDraw);const list=f.owner.list(e,f.light);assert.equal(list.length,1);const g=list[0].userData.nwnShadowAtlas;assert.equal(g.members.length,2);assert.equal(g.geometry.attributes.position.count,f.a.geometry.attributes.position.count+f.b.geometry.attributes.position.count);
 assert.equal(list[0].boundingSphere.radius,Infinity);assert.equal(g.multiCount,2);assert.equal(g.geometry.drawRange.count,f.a.geometry.index.count+f.b.geometry.index.count);
 for(let i=0;i<e.length;i++)for(const key of ['parent','geometry','material'])assert.equal(e[i].object[key],sources[i][key]);f.owner.end();assert.equal(f.renderer.renderBufferDirect,f.originalDraw);f.owner.reset();assert.equal(f.owner.snapshot().bytes,0);assert.equal(f.owner.snapshot().cachedGroups,0);assert.equal(sourceDisposals,0);
});
test('every face retains original membership and exact Float32 model-view/world values',()=>{
 const f=fixture(),e=f.entries();f.a.scale.set(1.3,.7,1.9);f.a.rotation.set(.23,.17,.39);f.scene.updateMatrixWorld(true);f.owner.begin(e);const proxy=f.owner.list(e,f.light)[0],g=proxy.userData.nwnShadowAtlas;
 f.light.shadow.getFrustum=()=>({intersectsSphere:s=>s.center.x>0});
 for(let i=0;i<6;i++){const c=f.light.shadow.camera;c.rotation.y=i*.4;c.updateMatrixWorld(true);void proxy.boundingSphere;assert.equal(g.multiCount,1);assert.equal(g.geometry.drawRange.count,f.a.geometry.index.count);assert.deepEqual([...g.matrixData.subarray(0,16)],[...new Float32Array(f.a.matrixWorld.elements)]);assert.deepEqual([...g.matrixData.subarray(16,32)],[...new Float32Array(new Matrix4().multiplyMatrices(c.matrixWorldInverse,f.a.matrixWorld).elements)]);const v=g.texture.version;void proxy.boundingSphere;assert.equal(g.texture.version,v);}
 f.light.shadow.camera.position.x++;f.light.shadow.camera.updateMatrixWorld(true);f.light.shadow.getFrustum=()=>({intersectsSphere:()=>false});void proxy.boundingSphere;assert.equal(g.multiCount,0);assert.equal(g.geometry.drawRange.count,0);f.owner.end();f.owner.dispose();
});
test('the portable index path uploads only selected ranges and restores COPY_WRITE binding',()=>{
 const f=fixture({multiDraw:false}),e=f.entries();f.owner.begin(e);const proxy=f.owner.list(e,f.light)[0],g=proxy.userData.nwnShadowAtlas;f.light.shadow.getFrustum=()=>({intersectsSphere:s=>s.center.x<0});void proxy.boundingSphere;
 const range=g.ranges[1];assert.deepEqual(f.writes.at(-1),[...g.indices.subarray(range.start,range.start+range.count)]);assert.equal(f.gl.bound,f.sentinel);assert.equal(f.gl.elementBound,f.sentinel);assert.equal(f.buffers.size,1);f.owner.end();f.owner.dispose();assert.equal(f.buffers.size,0);
});
test('multi-draw substitution restores the GL entry point even when the original draw throws',()=>{
 const f=fixture(),e=f.entries(),failure=Error('draw failure');f.renderer.renderBufferDirect=()=>{f.gl.drawElements(4,1,4,0);throw failure;};f.owner.begin(e);const proxy=f.owner.list(e,f.light)[0];void proxy.boundingSphere;
 assert.throws(()=>f.renderer.renderBufferDirect(null,null,proxy.geometry,null,proxy,null),x=>x===failure);assert.equal(f.gl.drawElements,f.drawElements);assert.equal(f.multiCalls.length,1);assert.equal(f.multiCalls[0].at(-1),2);f.owner.end();f.owner.dispose();
});
test('geometry edits and removed groups invalidate owned atlases without disposing sources',()=>{
 const f=fixture();let e=f.entries();f.owner.begin(e);f.owner.list(e,f.light);f.owner.end();const old=[...f.owner.groups.values()][0];let destroyed=0;old.geometry.addEventListener('dispose',()=>destroyed++);f.b.geometry=new BoxGeometry(2,3,4);e=f.entries();f.owner.begin(e);f.owner.list(e,f.light);f.owner.end();assert.equal(destroyed,1);assert.equal(f.owner.groups.size,1);
 f.owner.begin([e[0]]);assert.deepEqual(f.owner.list([e[0]],f.light),[f.a]);f.owner.end();assert.equal(f.owner.groups.size,0);assert.equal(f.owner.bytes,0);f.owner.dispose();
});
test('deformed, negative, custom and nonleaf producers fall back; layer and alpha differences do not merge',()=>{
 const f=fixture();for(const change of [()=>{f.b.userData.animationOwnedGeometry=true;},()=>{f.b.userData.animationOwnedGeometry=false;f.b.scale.x=-1;},()=>{f.b.scale.x=1;f.b.onBeforeShadow=()=>{};},()=>{f.b.onBeforeShadow=f.a.onBeforeShadow;f.b.add(new Group());}]){change();f.scene.updateMatrixWorld(true);const e=f.entries();f.owner.begin(e);assert.deepEqual(f.owner.list(e,f.light),[f.a,f.b]);f.owner.end();}
 f.b.clear();f.b.layers.set(2);let e=f.entries();f.owner.begin(e);assert.equal(f.owner.list(e,f.light).length,2);f.owner.end();f.b.layers.set(0);f.b.material.alphaTest=.3;e=f.entries();f.owner.begin(e);assert.equal(f.owner.list(e,f.light).length,2);f.owner.end();f.owner.dispose();
});
test('bounded allocation failure explicitly disables the experiment and keeps original draws',()=>{
 const f=fixture({maxBytes:1}),e=f.entries();f.owner.begin(e);assert.deepEqual(f.owner.list(e,f.light),[f.a,f.b]);f.owner.end();assert.equal(f.owner.snapshot().disabled,true);assert.match(f.owner.snapshot().failure,/memory limit/);assert.equal(f.owner.bytes,0);assert.equal(f.renderer.renderBufferDirect,f.originalDraw);f.owner.dispose();
});
test('draw order barriers and precision-sensitive front/two-sided shadows keep original submissions',()=>{
 const f=fixture(),extra=new Mesh(new BoxGeometry(),new MeshLambertMaterial({alphaTest:.5}));extra.castShadow=true;f.scene.add(extra);f.scene.updateMatrixWorld(true);const e=f.entries(),middle={object:extra,sphere:null};
 f.owner.begin([e[0],middle,e[1]]);assert.deepEqual(f.owner.list([e[0],middle,e[1]],f.light),[f.a,extra,f.b]);f.owner.end();
 for(const change of [()=>f.b.material.side=DoubleSide,()=>f.b.material.shadowSide=FrontSide]){change();f.owner.begin(e);assert.deepEqual(f.owner.list(e,f.light),[f.a,f.b]);f.owner.end();}f.owner.dispose();
});
