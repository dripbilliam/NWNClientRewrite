// Production functions are supplied as text by the test runner; importing
// src/main.js would boot the game. No replacement implementation of the builder.
import * as THREE from '../../node_modules/three/build/three.module.js';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {manageLocalMatrix} from '../../src/managed_local_matrix.js';
import {deformSkinnedVertices} from '../../src/model_skinning.js';
import {buildModelGeometry} from '../../src/prepared_model_geometry.js';
import {RendererModelGeometry} from '../../src/renderer_model_geometry.js';
import {modelMaterialOptions} from '../../src/model_material.js';
import {createModelEmitter} from '../../src/model_particles.js';
import {sampleEmitterParticle} from '../../src/particle_preview.js';

export function extractPreviewFactorySource(mainSource) {
  const range = (start,end) => {
    const a = mainSource.indexOf(start), b = mainSource.indexOf(end,a + start.length);
    if (a < 0 || b < 0 || mainSource.indexOf(start,a + start.length) !== -1) throw Error('Production function extraction drift: '+start);
    return mainSource.slice(a,b);
  };
  return [range('function buildObject(', 'function addModelLight('),
    range('function buildEmitterPreview(', 'function colorForName(')].join('\n');
}

export function createPreviewFactory(source,{checked=false}={}) {
  const checkbox = {checked}, pool = new RendererModelGeometry();
  const fail = name => () => {throw Error('Fixture unexpectedly called '+name);};
  const names = ['THREE','createModelHierarchy','manageLocalMatrix','deformSkinnedVertices','buildModelGeometry','rendererModelGeometry','modelMaterialOptions','createModelEmitter','sampleEmitterParticle','previewEffectsEnabled','prepareMatrixSubtrees','addModelLight'];
  const values = [THREE,createModelHierarchy,manageLocalMatrix,deformSkinnedVertices,buildModelGeometry,pool,modelMaterialOptions,createModelEmitter,sampleEmitterParticle,checkbox,false,fail('addModelLight')];
  const methods = new Function(...names,source+'\nreturn {buildObject,updateEmitterPreviewVisibility,updateEmitterPreviews};')(...values);
  return {...methods,checkbox,pool};
}

export function authoredPreviewModel({emitters=2,birthRate=16,life=2}={}) {
  const base = (name,type,parent='root') => ({name,type,parent,position:[0,0,0],orientation:[0,0,0,0],scale:1,properties:{}});
  const mesh = {...base('body','trimesh'),verts:[[-1,-1,0],[1,-1,0],[1,1,0],[-1,1,0],[0,0,3]],tverts:[[0,0],[1,0],[1,1],[0,1],[.5,.5]],
    faces:[[0,1,4,0,0,1,4,0],[1,2,4,0,1,2,4,1],[2,3,4,0,2,3,4,0],[3,0,4,0,3,0,4,1]],bitmaps:['surface','detail'],diffuse:[1,1,1]};
  return {modelName:'authored_preview_audit',nodes:[base('root','dummy','NULL'),mesh,
    ...Array.from({length:emitters},(_,i)=>({...base('flame'+i,'emitter'),position:[i*.3,0,1],properties:{texture:'spark',update:'Fountain',render:'Normal',blend:'Normal',birthrate:birthRate,lifeexp:life,velocity:.5,spread:.3,sizestart:.25,sizeend:.5,colorstart:[1,.7,.4],colorend:[.8,.2,.1],alphastart:.8,alphaend:0,xgrid:2,ygrid:2,frameend:3,fps:4}}))]};
}

export function fixtureTextures() {
  return new Map(['surface','detail','spark'].map((name,i)=>{
    const data=Uint8Array.from({length:64},(_,j)=>j%4===3?(j%12===3?0:255):(j*17+i*53)%256);
    const texture=new THREE.DataTexture(data,4,4); texture.colorSpace=THREE.SRGBColorSpace; texture.needsUpdate=true;
    return [name,texture];
  }));
}

export function previewCounts(root) {
  const counts={nodes:0,previews:0,sprites:0,emitters:0};
  root.traverse(object=>{counts.nodes++;if(object.userData.emitterPreview)counts.previews++;if(object.isSprite)counts.sprites++;if(object.userData.mdlEmitter)counts.emitters++;});
  return counts;
}

export function disposePreviewFixture(root,factory,textures,presentation) {
  // Native particle presentation disposes its own meshes. Skip them below.
  const runtimeOwned=new Set([...presentation?.entries.keys()??[]]);
  const maps=new Set(textures.values());
  root.traverse(object=>{for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[])if(material.map)maps.add(material.map);});
  presentation?.dispose();
  root.traverse(object=>{
    if(runtimeOwned.has(object))return;
    if(object.geometry&&!factory.pool.release(object))object.geometry.dispose();
    for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[])material.dispose();
  });
  for(const texture of maps)texture.dispose();
  root.removeFromParent();
}

export function particleState(presentation) {
  return {random:{state:presentation.random.state,draws:presentation.random.draws},summary:presentation.snapshot(),
    entries:[...presentation.entries.values()].map(entry=>({failed:entry.failed,
      attributes:Object.fromEntries(Object.entries(entry.mesh.geometry.attributes).map(([name,attribute])=>[name,[...attribute.array]])),
      drawRange:{...entry.mesh.geometry.drawRange},active:entry.e?.active188.records,free:entry.e?.free130.records}))};
}

// Native particles point back to their emitter and its active/free lists.
// Preserve cycles, alias identity and exceptional numeric values in the GPU
// oracle rather than dropping fields to make JSON.stringify succeed.
export function particleGraphSignature(state) {
  const seen=new Map();
  function encode(value) {
    if(value===undefined)return {$undefined:true};
    if(typeof value==='number')return Number.isFinite(value)&&!Object.is(value,-0)?value:{$number:Object.is(value,-0)?'-0':String(value)};
    if(value===null||typeof value==='string'||typeof value==='boolean')return value;
    if(typeof value!=='object')throw Error('Unsupported particle oracle value: '+typeof value);
    if(seen.has(value))return {$ref:seen.get(value)};
    const id=seen.size;seen.set(value,id);
    if(value instanceof ArrayBuffer)return {$id:id,type:'ArrayBuffer',bytes:[...new Uint8Array(value)]};
    if(ArrayBuffer.isView(value))return {$id:id,type:value.constructor.name,bytes:[...new Uint8Array(value.buffer,value.byteOffset,value.byteLength)]};
    if(Array.isArray(value))return {$id:id,type:'Array',values:value.map(encode)};
    return {$id:id,type:Object.getPrototypeOf(value)?.constructor?.name??null,values:Object.fromEntries(Object.keys(value).sort().map(key=>[key,encode(value[key])]))};
  }
  return JSON.stringify(encode(state));
}
