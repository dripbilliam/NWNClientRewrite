import test from 'node:test';import assert from 'node:assert/strict';import {Scene,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,Texture,WebGLRenderTarget} from 'three';import {RendererPointShadowCache} from '../src/renderer_point_shadow_cache.js';
function fixture(){const scene=new Scene(),mesh=new Mesh(new BoxGeometry(),new MeshLambertMaterial()),light=new PointLight(0xffffff,1,10),cache=new RendererPointShadowCache();mesh.castShadow=true;light.shadow.map=new WebGLRenderTarget(1,1);scene.add(mesh,light);const plan=(objects=[mesh],force=false)=>{scene.updateMatrixWorld(true);cache.begin();return cache.plan(light,objects,2,{force});};const commit=()=>{const p=plan();cache.commit(light,p,2);};return{scene,mesh,light,cache,plan,commit};}
test('unchanged point maps reuse while light color changes do not dirty shadow geometry',()=>{
 const f=fixture();assert.equal(f.plan().reuse,false);f.commit();assert.equal(f.plan().reuse,true);f.light.color.set(0x445566);f.light.intensity=4;assert.equal(f.plan().reuse,true);assert.equal(f.plan([],false).reuse,false);assert.equal(f.plan([f.mesh],true).reuse,false);
});
test('light pose, projection, target lifecycle and caster changes invalidate cached maps',()=>{
 const f=fixture();for(const change of [()=>f.mesh.position.x++,()=>{f.mesh.geometry.attributes.position.needsUpdate=true;},()=>f.mesh.geometry.setDrawRange(0,3),()=>f.mesh.layers.set(1),()=>{f.mesh.material.alphaTest=.5;},()=>{f.mesh.material.opacity=.2;},()=>{f.mesh.material.map=new Texture();},()=>{f.mesh.material.map.offset.x=.5;},()=>{f.mesh.material.map.needsUpdate=true;},()=>f.light.position.y++,()=>{f.light.distance=12;},()=>{f.light.shadow.camera.near=.2;},()=>{f.light.shadow.mapSize.x=256;},()=>f.light.shadow.map.dispose()]){f.commit();assert.equal(f.plan().reuse,true);change();assert.equal(f.plan().reuse,false);}
 f.commit();f.cache.restore();assert.equal(f.plan().reuse,false);
});
test('custom shadow hooks/materials and unsupported mesh producers always stay live',()=>{
 const f=fixture();for(const change of [()=>{f.mesh.onBeforeShadow=()=>{};},()=>{f.mesh.onBeforeShadow=undefined;},()=>{f.mesh.customDistanceMaterial={};},()=>{f.mesh.isInstancedMesh=true;}]){change();f.commit();assert.equal(f.plan().reuse,false);}
});

test('volatile-map candidate stops redundant input inspection but still redraws the complete map',()=>{
 const f=fixture(),other=f.mesh.clone();f.cache.shortCircuitVolatile=true;f.mesh.customDistanceMaterial={};
 const seen=[],stamp=f.cache.stamp;f.cache.stamp=function(object){seen.push(object);return stamp.call(this,object);};
 const first=f.plan([f.mesh,other]);assert.equal(first.reuse,false);assert.equal(first.inputs,null);assert.deepEqual(seen,[f.mesh]);f.cache.commit(f.light,first,2);
 seen.length=0;other.position.x=5;other.updateMatrixWorld(true);assert.equal(f.plan([f.mesh,other]).reuse,false);assert.deepEqual(seen,[f.mesh]);
 f.cache.shortCircuitVolatile=false;seen.length=0;const baseline=f.plan([f.mesh,other]);assert.equal(baseline.reuse,false);assert.equal(baseline.inputs.length,4);assert.deepEqual(seen,[f.mesh,other]);
});

test('removing the volatile producer requires a full rendered baseline before reuse',()=>{
 const f=fixture(),volatile=f.mesh.clone();volatile.customDistanceMaterial={};f.cache.shortCircuitVolatile=true;
 const p=f.plan([volatile,f.mesh]);f.cache.commit(f.light,p,2);f.mesh.position.x=3;
 const ordinary=f.plan();assert.equal(ordinary.reuse,false);assert.equal(ordinary.inputs.length,2);f.cache.commit(f.light,ordinary,2);assert.equal(f.plan().reuse,true);
 f.mesh.geometry.attributes.position.needsUpdate=true;assert.equal(f.plan().reuse,false);f.commit();assert.equal(f.plan().reuse,true);
 f.cache.restore();assert.equal(f.plan().reuse,false);
});

test('volatile-map early exit is disabled in the production constructor',()=>{
 const f=fixture();assert.equal(f.cache.shortCircuitVolatile,false);f.mesh.customDistanceMaterial={};assert.equal(f.plan().inputs.length,2);
});
