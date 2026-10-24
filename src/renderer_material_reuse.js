import {Object3D,Material,MeshLambertMaterial} from 'three';
import {isLocalRendererHook,rendererBatchHook} from './renderer_local_hooks.js';
const ob=Object3D.prototype,mb=Material.prototype;
const maps=['map','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','alphaMap','envMap'];
const fields=['side','flatShading','vertexColors','opacity','alphaTest','lightMapIntensity','aoMapIntensity','emissiveIntensity','bumpScale','normalMapType','displacementScale','displacementBias','combine','reflectivity','refractionRatio','fog','blending','blendSrc','blendDst','blendEquation','blendSrcAlpha','blendDstAlpha','blendEquationAlpha','blendAlpha','depthFunc','depthTest','depthWrite','stencilWriteMask','stencilFunc','stencilRef','stencilFuncMask','stencilFail','stencilZFail','stencilZPass','stencilWrite','colorWrite','precision','polygonOffset','polygonOffsetFactor','polygonOffsetUnits','dithering','alphaToCoverage','premultipliedAlpha','forceSinglePass','allowOverride','toneMapped','clipIntersection','clipShadows'];
const unknown=(hook,base)=>hook!==base&&!isLocalRendererHook(hook);

// Reuse only the material of the immediately preceding equivalent draw. The
// already sorted render list retains EVERY object, geometry and draw in its
// original order. Source materials, animation bindings and picking stay owned
// by their existing producers; no GPU resources or canonical clones are made.
export class RendererMaterialReuse{
 constructor(renderer,{enabled=true}={}){this.renderer=renderer;this.enabled=enabled;this.running=false;this.reset();this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);}
 reset(){this.shaders=new WeakMap();this.stats={draws:0,reused:0,keyholeStates:0};}
 shader(material){
  let state=this.shaders.get(material);
  if(state&&state.compile===material.onBeforeCompile&&state.key===material.customProgramCacheKey&&state.version===material.version)return state;
  const tokens=[];let hook=material.onBeforeCompile,keyhole=null;
  while(hook!==mb.onBeforeCompile){const d=rendererBatchHook(hook);if(!d||!['target-preview','keyhole'].includes(d.kind)||tokens.includes(d.token))return null;tokens.push(d.token);if(d.kind==='keyhole'){if(keyhole)return null;keyhole=d;}hook=d.before;}
  if(unknown(material.customProgramCacheKey,mb.customProgramCacheKey))return null;
  state={compile:material.onBeforeCompile,key:material.customProgramCacheKey,version:material.version,cacheKey:material.customProgramCacheKey(),tokens,keyhole};this.shaders.set(material,state);return state;
 }
 eligible(item,lightVersion){
  const {object:o,material:m}=item;
  if(m.constructor!==MeshLambertMaterial||m.transparent||m.wireframe||m.alphaHash||m.defines||m.uniforms||m.clippingPlanes?.length||!o.isMesh||o.isSkinnedMesh||o.isInstancedMesh||o.isBatchedMesh)return null;
  const shader=this.shader(m);if(!shader)return null;
  // Keep each source's program initialization/invalidation path intact. A
  // never-drawn material or one with pending changes must first draw normally.
  // This also retains source program history across renderer-wide mode changes.
  const properties=this.renderer.properties.get(m);
  if(!properties.currentProgram||properties.__version!==m.version||properties.lightsStateVersion!==lightVersion)return null;
  shader.program=properties.currentProgram;
  const hook=rendererBatchHook(o.onBeforeRender);
  if(shader.keyhole){if(hook?.kind!=='keyhole-state'||hook.token!==shader.keyhole.token||hook.can!==shader.keyhole.can)return null;}
  else if(o.onBeforeRender!==ob.onBeforeRender)return null;
  return shader;
 }
 equal(a,b,sa,sb){
  if(sa.program!==sb.program||sa.cacheKey!==sb.cacheKey||sa.tokens.length!==sb.tokens.length||sa.tokens.some((token,i)=>token!==sb.tokens[i])||sa.keyhole?.can.value!==sb.keyhole?.can.value)return false;
  for(const key of maps)if(a[key]!==b[key])return false;
  if(!a.color.equals(b.color)||!a.emissive.equals(b.emissive)||!a.normalScale.equals(b.normalScale)||!a.envMapRotation.equals(b.envMapRotation)||!a.blendColor.equals(b.blendColor))return false;
  for(const key of fields)if(a[key]!==b[key])return false;
  return true;
 }
 compatible(list){
  if(list.transmissive.length)return false;
  const textures=new Set();
  for(const items of [list.opaque,list.transparent])for(const {object:o,material:m}of items){
   if(unknown(o.onBeforeRender,ob.onBeforeRender)||o.onAfterRender!==ob.onAfterRender||m.onBeforeRender!==mb.onBeforeRender||unknown(m.onBeforeCompile,mb.onBeforeCompile)||unknown(m.customProgramCacheKey,mb.customProgramCacheKey))return false;
   for(const key of maps)if(m[key])textures.add(m[key]);
   for(const entry of Object.values(m.uniforms??{})){const value=entry?.value;if(value?.isTexture)textures.add(value);else if(Array.isArray(value))for(const v of value)if(v?.isTexture)textures.add(v);}
  }
  for(const texture of textures)if(texture.onUpdate)return false;
  return true;
 }
 patch(list,scene,camera,start,lightVersion){
  const original=list.opaque;this.stats.draws=original.length;
  const hooks=new Map(),changed=[];let previous=start?original[start-1]:null,previousShader=previous?this.eligible(previous,lightVersion):null;if(!previousShader)previous=null;
  const restore=()=>{for(let i=0;i<changed.length;i+=2)changed[i].material=changed[i+1];for(const [object,hook]of hooks)object.onBeforeRender=hook;};
  try{
   for(let i=start;i<original.length;i++){const item=original[i];
    const saved=hooks.get(item.object);if(saved)item.object.onBeforeRender=saved;
    const shader=this.eligible(item,lightVersion);
    if(saved||shader?.keyhole){const hook=item.object.onBeforeRender;hook.call(item.object,this.renderer,scene,camera,item.geometry,item.material,item.group);hooks.set(item.object,hook);this.stats.keyholeStates++;}
    if(saved||shader?.keyhole)item.object.onBeforeRender=ob.onBeforeRender;
    if(shader&&previousShader&&item.object.receiveShadow===previous.object.receiveShadow&&this.equal(item.material,previous.material,shader,previousShader)){
     if(item.material!==previous.material){changed.push(item,item.material);item.material=previous.material;this.stats.reused++;}
    }else{previous=shader?item:null;previousShader=shader;}
   }
   return restore;
  }catch(error){restore();throw error;}
 }
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  this.stats={draws:0,reused:0,keyholeStates:0};
  if(!this.enabled||this.running||scene.overrideMaterial||scene.onBeforeRender!==ob.onBeforeRender||scene.onAfterRender!==ob.onAfterRender||camera.isArrayCamera||this.renderer.xr?.enabled)return draw();
  // Three finalizes its current light-layout version AFTER shadow rendering.
  // Let the first lit main draw run normally, then read that actual version.
  // Sources that still require a light/program refresh remain ordinary draws.
  const renderer=this.renderer,before=renderer.renderBufferDirect,map=renderer.shadowMap,shadow=map.render;let restore,ready=false,opaque=null,shadowDepth=0;this.running=true;
  // Validate before any main draw: an unknown callback could clear itself on
  // that first draw. Nested rendering during shadows cannot start this pass.
  map.render=(lights,s,c)=>{shadowDepth++;let result;try{result=shadow.call(map,lights,s,c);}finally{shadowDepth--;}if(shadowDepth===0&&s===scene&&c===camera){const list=renderer.renderLists.get(scene,0);try{ready=this.compatible(list);opaque=list.opaque;this.stats.draws=opaque.length;if(!ready)this.stats.fallback='render-callback';}catch{this.stats.fallback='preparation-failed';}if(!ready)renderer.renderBufferDirect=before;}return result;};
  renderer.renderBufferDirect=(c,s,g,m,o,group)=>{
   const result=before.call(renderer,c,s,g,m,o,group);
   if(ready&&shadowDepth===0&&s===scene&&c===camera&&m.isMeshLambertMaterial){
    renderer.renderBufferDirect=before;
    const list=renderer.renderLists.get(scene,0),index=list.opaque.findIndex(item=>item.object===o&&item.geometry===g&&item.material===m&&item.group===group);
    if(index>=0&&list.opaque===opaque)try{restore=this.patch(list,scene,camera,index+1,renderer.properties.get(m).lightsStateVersion);}catch{this.stats.fallback='preparation-failed';}
   }
   return result;
  };
  try{return draw();}finally{restore?.();renderer.renderBufferDirect=before;map.render=shadow;this.running=false;}
 }
 snapshot(){return{...this.stats,enabled:this.enabled,materialsHeld:0};}
 dispose(){this.reset();this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
