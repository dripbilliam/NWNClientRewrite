import test from 'node:test';
import assert from 'node:assert/strict';
import {Mesh,BoxGeometry,MeshLambertMaterial,Matrix4,Vector3,Quaternion,Color,Sphere} from 'three';
import {pointBufferShader,pointLightIndices,packPointLights} from '../src/renderer_point_light_buffer.js';
const light=(x,{distance=1,color=1,decay=2}={})=>({position:new Vector3(x,0,0),distance,color:new Color(color),decay});
const fixture=()=>{const object=new Mesh(new BoxGeometry(1,1,1),new MeshLambertMaterial());object.modelViewMatrix.identity();return{object,material:object.material,indices:new Int32Array(128)};};

test('point shader keeps original fallback and constant shadow sampler indexing, adding no texture sampler',()=>{
 const shader={fragmentShader:'#include <lights_pars_begin>\nvoid main(){\n#include <lights_fragment_begin>\n}',uniforms:{}};pointBufferShader(shader);
 assert.match(shader.fragmentShader,/layout\(std140\) uniform NwnPointLights/);assert.match(shader.fragmentShader,/nwnReadPoint\( UNROLLED_LOOP_INDEX \)/);assert.match(shader.fragmentShader,/i < NUM_POINT_LIGHT_SHADOWS/);assert.match(shader.fragmentShader,/nwnReadPoint\(nwnObjectPointIndices\[nwnLight\]\)/);assert.match(shader.fragmentShader,/uniform PointLight pointLights\[ NUM_POINT_LIGHTS \]/);assert.doesNotMatch(shader.fragmentShader,/uniform sampler2D nwn/);assert.equal(shader.uniforms.nwnObjectPointIndices.value.length,128);
});

test('nonshadow lists preserve source order, finite range, infinite lights and exact-zero padding',()=>{
 const {object,material,indices}=fixture(),lights=[light(0),light(0),light(1),light(10),light(100,{distance:0}),light(0,{color:0})];
 const count=pointLightIndices(lights,2,object,material,indices);assert.deepEqual([...indices.slice(0,count)],[2,4]);
});

test('animated, skinned, displaced, morphing and modified geometry conservatively retain finite nonzero lights',()=>{
 for(const mode of ['animation','skin','displacement','morph','modified']){const f=fixture();if(mode==='animation')f.object.userData.animationOwnedGeometry=true;if(mode==='skin')f.object.isSkinnedMesh=true;if(mode==='displacement')f.material.displacementMap={};if(mode==='morph')f.object.geometry.morphAttributes.position=[f.object.geometry.attributes.position.clone()];if(mode==='modified')f.object.geometry.attributes.position.needsUpdate=true;assert.equal(pointLightIndices([light(100)],0,f.object,f.material,f.indices),1,mode);}
});

test('GPU cutoff underflow and nonfinite light data remain conservative',()=>{
 const f=fixture(),lights=[light(100,{distance:1e-300}),light(100,{color:0,decay:NaN}),light(100,{distance:1,color:1})];lights[2].color.r=Infinity;
 assert.equal(pointLightIndices(lights,0,f.object,f.material,f.indices),3);
});

// Prepared during the actual-tests hold; do not treat as a passing result.
test('legacy quadratic lights retain their nonzero tails beyond authored radius, including packed snapshots',()=>{
 const f=fixture(),lights=[light(100,{distance:1,decay:-4.5}),light(100,{distance:-1,decay:-4.5}),light(100,{distance:1,decay:2}),light(100,{distance:1,decay:-Number.MIN_VALUE}),light(100,{distance:1,decay:NaN})];
 // The ordinary native-light adapter remains nonzero at this distance. The
 // finite standard Three light does not reach the box. The tiny negative
 // decay rounds to -0 in the shader and takes the standard finite branch.
 assert.ok(1/(1+4.5*100*100)>0);
 for(const packed of [null,{data:new Float32Array(1024),states:new Uint8Array(128)}]){
  if(packed)packPointLights(lights,packed.data,packed.states);
  const count=pointLightIndices(lights,0,f.object,f.material,f.indices,new Sphere(),packed);
  assert.deepEqual([...f.indices.slice(0,count)],[0,1,4],packed?'packed':'direct');
 }
 f.object.geometry.dispose();f.material.dispose();
});

test('legacy range eligibility uses the uploaded float32 snapshot rather than later source mutation',()=>{
 const f=fixture(),lights=[light(100,{distance:1,decay:-4.5})],packed={data:new Float32Array(1024),states:new Uint8Array(128)};
 packPointLights(lights,packed.data,packed.states);lights[0].decay=2;
 assert.equal(pointLightIndices(lights,0,f.object,f.material,f.indices,new Sphere(),packed),1);
 assert.equal(pointLightIndices(lights,0,f.object,f.material,f.indices),0);
 f.object.geometry.dispose();f.material.dispose();
});

test('one packed float32 light snapshot preserves source data and conservative per-object results',()=>{
 const f=fixture(),lights=[light(2,{distance:1.2}),light(20),light(100,{distance:1e-300}),light(1,{color:0}),light(100,{decay:NaN})],data=new Float32Array(1024),states=new Uint8Array(128),before=lights.map(value=>value.position.toArray());
 packPointLights(lights,data,states);assert.deepEqual([...states.slice(0,5)],[2,2,2,1,0]);assert.equal(data[3],Math.fround(lights[0].distance));assert.equal(data[11],0);assert.deepEqual(lights.map(value=>value.position.toArray()),before);
 const count=pointLightIndices(lights,0,f.object,f.material,f.indices,new Sphere(),{data,states});assert.deepEqual([...f.indices.slice(0,count)],[0,2,4]);
});

test('translated, rotated, negative and sheared rigid bounds never omit a light reaching any tested source vertex',()=>{
 let seed=109;const random=()=>((seed=Math.imul(seed,1664525)+1013904223)>>>0)/2**32;let checks=0;
 for(let trial=0;trial<80;trial++){
  const f=fixture(),q=new Quaternion().setFromAxisAngle(new Vector3(.2,.7,.3).normalize(),random()*6),parent=new Matrix4().compose(new Vector3(random()*30-15,random()*10,random()*30-15),q,new Vector3(random()*3+.1,random()*3+.1,random()*3+.1));
  f.object.modelViewMatrix.copy(parent).multiply(new Matrix4().makeRotationY(random()*6)).scale(new Vector3(trial%2?-1:1,.7,1.3));
  const vertices=[],p=f.object.geometry.attributes.position;for(let i=0;i<p.count;i++)vertices.push(new Vector3().fromBufferAttribute(p,i).applyMatrix4(f.object.modelViewMatrix));
  const lights=Array.from({length:64},(_,i)=>({position:i%2?vertices[i%vertices.length].clone().add(new Vector3(random()-.5,random()-.5,random()-.5)):new Vector3(random()*60-30,random()*20,random()*60-30),distance:random()*5+.1,color:new Color(1),decay:2}));
  const count=pointLightIndices(lights,0,f.object,f.material,f.indices),chosen=new Set(f.indices.slice(0,count));
  for(const [index,l]of lights.entries())for(const vertex of vertices){checks++;if(vertex.distanceTo(l.position)<Math.fround(l.distance))assert.ok(chosen.has(index),`trial ${trial}, light ${index}`);}
  f.object.geometry.dispose();f.material.dispose();
 }assert.ok(checks>100000);
});
