import {Material,REVISION} from 'three';

// Three r180 owns program refcounts through material disposal. Keep a bounded
// set of finished, PRIVATE preparation materials as leases; never increment a
// program refcount or transfer renderer properties to a different material.
// Leases are never drawn/compiled again. Drop their scene/uniform/texture and
// callback references before retaining them, leaving normal disposal intact.
export class RendererProgramCache{
 constructor(renderer,{maxPrograms=128,maxBytes=8*1024*1024}={}){
  this.renderer=renderer;this.maxPrograms=maxPrograms;this.maxBytes=maxBytes;this.entries=new Map();this.programs=new Map();this.references=0;this.bytes=0;this.epoch=0;this.closed=false;
  this.supported=REVISION==='180'&&typeof renderer.properties?.get==='function';this.stats={retained:0,hits:0,evicted:0};
  this.lost=()=>this.clear();renderer.domElement?.addEventListener('webglcontextlost',this.lost);
 }
 adopt(material,epoch=this.epoch){
  if(this.closed||!this.supported||epoch!==this.epoch||this.entries.has(material)||material._listeners?.dispose?.length!==1)return false;
  const properties=this.renderer.properties.get(material),programs=properties.programs;
  if(!(programs instanceof Map)||!programs.size)return false;
  const values=[...new Set(programs.values())];
  if(values.some(program=>!program.program||!this.renderer.info.programs.includes(program)||!program.isReady()))return false;
  if(values.every(program=>this.programs.has(program))){
   const touched=new Set(values.flatMap(program=>[...this.programs.get(program)]));for(const owner of touched){const entry=this.entries.get(owner);this.entries.delete(owner);this.entries.set(owner,entry);}this.stats.hits++;return false;
  }
  const bytes=[...programs.keys()].reduce((n,key)=>n+String(key).length*2,0)+(material.vertexShader?.length??0)*2+(material.fragmentShader?.length??0)*2;
  if(values.length>this.maxPrograms||bytes>this.maxBytes)return false;
  // Only ordinary writable data properties are stripped. Unknown producers
  // keep the original disposal path, including their listeners and ownership.
  for(const [key,descriptor]of Object.entries(Object.getOwnPropertyDescriptors(material)))if(descriptor.get||descriptor.set||key!=='_listeners'&&descriptor.value!==null&&['object','function'].includes(typeof descriptor.value)&&!descriptor.writable)return false;
  if(Object.values(Object.getOwnPropertyDescriptors(properties)).some(descriptor=>!descriptor.configurable))return false;
  while(this.entries.size&&(this.references+values.length>this.maxPrograms||this.bytes+bytes>this.maxBytes))this.evict(this.entries.keys().next().value);
  for(const key of Object.keys(properties))if(key!=='programs')delete properties[key];
  for(const key of Object.keys(material))if(key!=='_listeners'&&material[key]!==null&&['object','function'].includes(typeof material[key]))material[key]=null;
  material.onBeforeCompile=Material.prototype.onBeforeCompile;material.customProgramCacheKey=Material.prototype.customProgramCacheKey;material.onBeforeRender=Material.prototype.onBeforeRender;
  material.userData={};if(material.isShaderMaterial){material.uniforms={};material.vertexShader='';material.fragmentShader='';}
  this.entries.set(material,{programs:values,bytes});for(const program of values){let owners=this.programs.get(program);if(!owners)this.programs.set(program,owners=new Set());owners.add(material);}this.references+=values.length;this.bytes+=bytes;this.stats.retained++;return true;
 }
 evict(material){const entry=this.entries.get(material);if(!entry)return;this.entries.delete(material);for(const program of entry.programs){const owners=this.programs.get(program);owners.delete(material);if(!owners.size)this.programs.delete(program);}this.references-=entry.programs.length;this.bytes-=entry.bytes;material.dispose();this.stats.evicted++;}
 clear(){this.epoch++;for(const material of [...this.entries.keys()])this.evict(material);}
 snapshot(){return{...this.stats,materials:this.entries.size,programs:this.programs.size,references:this.references,bytes:this.bytes,maxPrograms:this.maxPrograms,maxBytes:this.maxBytes,epoch:this.epoch,supported:this.supported,closed:this.closed};}
 dispose(){if(this.closed)return;this.closed=true;this.clear();this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
