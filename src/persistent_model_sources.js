// Base data only: no inherited clips, scene nodes, actors, WebGL handles or
// clocks. New resource contexts validate authoritative bytes, so equal resrefs
// from different servers cannot alias. A mounted native connection has one
// immutable resolver; its area changes reuse already validated bases directly.
export class PersistentModelSources{
 constructor({maxBytes=256*1024*1024}={}){this.maxBytes=maxBytes;this.entries=new Map();this.bytes=0;this.generation=0;this.stats={requests:0,hits:0,contextHits:0,misses:0,evicted:0};}
 async load(name,read,{context=null}={}){
  const generation=this.generation,key=name.toLowerCase(),previous=this.entries.get(key);this.stats.requests++;
  const local=context!==null&&previous?.context===context;
  const result=local?{key:previous.key,reused:true}:await read(key,previous?.key??null);let base;
  if(result.reused){if(!previous||previous.key!==result.key)throw Error('Prepared model validation has no matching base');base=previous.model;this.stats.hits++;if(local)this.stats.contextHits++;}
  else{if(!result.model||!Array.isArray(result.model.nodes)||typeof result.key!=='string'||!Number.isFinite(result.bytes)||result.bytes<0)throw Error('Invalid prepared model response');base=result.model;this.stats.misses++;}
  for(const node of base.nodes)if(node.properties)Object.setPrototypeOf(node.properties,null);
  if(generation===this.generation){
   const record=result.reused?{...previous,context}:{key:result.key,model:base,bytes:result.bytes,context},old=this.entries.get(key);if(old){this.bytes-=old.bytes;this.entries.delete(key);}
   if(record.bytes<=this.maxBytes){this.entries.set(key,record);this.bytes+=record.bytes;}
   while(this.bytes>this.maxBytes){const[name,entry]=this.entries.entries().next().value;this.entries.delete(name);this.bytes-=entry.bytes;this.stats.evicted++;}
  }
  // inheritAnimations appends to these arrays and replaces flags on the model;
  // the own clips/nodes remain immutable, as already shared by live instances.
  return{...base,animations:base.animations.slice(),unsupportedAnimations:base.unsupportedAnimations.slice()};
 }
 clear(){this.generation++;this.entries.clear();this.bytes=0;}
 snapshot(){return{...this.stats,bytes:this.bytes,entries:this.entries.size,limit:this.maxBytes};}
}
