import {Object3D,Material} from 'three';
import {isLocalRendererHook} from './renderer_local_hooks.js';

// Numeric lights are scene/camera state, and GL uniforms belong to a program,
// not a material. Three's ordinary path re-walks their structured arrays when
// returning to a program. Cache only within one supported main-camera pass.
// Samplers MUST remain ordinary: their setters allocate/bind texture units.
// Keep Three's frequent light-flag stores as ordinary data properties. Accessor
// flags there deoptimized its hot markUniformsLightsNeedsUpdate loop in v23.
// Shadow matrices are numeric arrays uploaded on EVERY material change; their
// needsUpdate flags are not touched by that loop.
const fields=['directionalShadowMatrix','spotLightMatrix','pointShadowMatrix'];
const unknown=(hook,base)=>hook!==base&&!isLocalRendererHook(hook);
const objectBase=Object3D.prototype,materialBase=Material.prototype;

export class RendererLightUniforms{
 constructor(renderer,{enabled=true}={}){
  this.renderer=renderer;this.enabled=enabled;this.records=new Map();this.textureFields=new WeakMap();this.active=false;this.running=false;this.programs=new WeakMap();this.stats={uploads:0,skipped:0};
  this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);
 }
 restore(record){
  for(const item of record.fields){const current=Object.getOwnPropertyDescriptor(item.uniform,'needsUpdate');if(current?.get!==item.get)continue;if(item.previous)Object.defineProperty(item.uniform,'needsUpdate',item.previous);else delete item.uniform.needsUpdate;}
 }
 reset(){for(const record of this.records.values())this.restore(record);this.records.clear();this.active=false;this.programs=new WeakMap();this.stats={uploads:0,skipped:0};}
 install(material){
  const properties=this.renderer.properties.get(material),uniforms=properties.uniforms;
  let record=this.records.get(material);if(record?.uniforms===uniforms)return;
  if(record){this.restore(record);this.records.delete(material);}
  if(!properties.needsLights||!uniforms)return;
  record={uniforms,fields:[]};
  for(let i=0;i<fields.length;i++){
   const uniform=uniforms[fields[i]];if(!uniform)continue;
   const previous=Object.getOwnPropertyDescriptor(uniform,'needsUpdate');
   if(previous&&(!previous.configurable||previous.get||previous.set))continue;
   let requested=uniform.needsUpdate;
   const get=()=>{
    if(!this.active||requested===false)return requested;
    const program=properties.currentProgram;if(!program)return requested;
    if(record.pass!==this.pass||record.program!==program){record.pass=this.pass;record.program=program;record.state=this.programs.get(program);if(!record.state){record.state={mask:0};this.programs.set(program,record.state);}}
    const bit=1<<i;
    if(record.state.mask&bit){this.stats.skipped++;return false;}
    record.state.mask|=bit;this.stats.uploads++;return requested;
   };
   Object.defineProperty(uniform,'needsUpdate',{configurable:true,enumerable:previous?.enumerable??true,get,set:value=>{requested=value;}});
   record.fields.push({uniform,previous,get});
  }
  this.records.set(material,record);
 }
 prepare(list){
  // Unknown draw/texture callbacks can change lighting or re-enter rendering.
  // Keep the complete pass ordinary in that case, including already installed
  // descriptors (their inactive getters simply return Three's requested flag).
  const materials=new Set();
  if(list.transmissive.length)return false;
  for(const items of [list.opaque,list.transparent])for(const {object:o,material:m}of items){
   if(unknown(o.onBeforeRender,objectBase.onBeforeRender)||o.onAfterRender!==objectBase.onAfterRender||m.onBeforeRender!==materialBase.onBeforeRender||unknown(m.onBeforeCompile,materialBase.onBeforeCompile)||unknown(m.customProgramCacheKey,materialBase.customProgramCacheKey)||(m.isShaderMaterial||m.isRawShaderMaterial)&&m.lights)return false;
   materials.add(m);
  }
  for(const m of materials){
   let schema=this.textureFields.get(m);if(!schema||schema.version!==m.version){schema={version:m.version,keys:Object.keys(m).filter(key=>m[key]===null||m[key]?.isTexture)};this.textureFields.set(m,schema);}
   for(const key of schema.keys)if(m[key]?.isTexture&&m[key].onUpdate)return false;
   for(const entry of Object.values(m.uniforms??{})){const value=entry?.value;if(value?.isTexture&&value.onUpdate||Array.isArray(value)&&value.some(v=>v?.isTexture&&v.onUpdate))return false;}
   this.install(m);
  }
  for(const [m,record]of this.records)if(!materials.has(m)){this.restore(record);this.records.delete(m);}
  return true;
 }
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  if(this.running){const old=this.active;this.active=false;try{return draw();}finally{this.active=old;this.programs=new WeakMap();this.pass={};}}
  this.stats={uploads:0,skipped:0};this.programs=new WeakMap();this.pass={};
  if(!this.enabled||scene.overrideMaterial||scene.onBeforeRender!==objectBase.onBeforeRender||scene.onAfterRender!==objectBase.onAfterRender||camera.isArrayCamera||this.renderer.xr?.enabled){this.stats.fallback='unsupported-pass';return draw();}
  const renderer=this.renderer,map=renderer.shadowMap,before=map.render;this.running=true;
  map.render=(lights,s,c)=>{
   const value=before.call(map,lights,s,c);
   if(s===scene&&c===camera){try{this.active=this.prepare(renderer.renderLists.get(scene,0));if(!this.active)this.stats.fallback='render-callback';}catch{this.active=false;this.stats.fallback='preparation-failed';}}
   return value;
  };
  try{return draw();}finally{this.active=false;this.running=false;map.render=before;}
 }
 snapshot(){return{...this.stats,enabled:this.enabled,materials:this.records.size};}
 dispose(){this.reset();this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
