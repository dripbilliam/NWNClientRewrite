// Preupload through Three's ordinary texture initialization path. The area
// owns source images; this cache stores only per-texture promises/versions and
// never disposes, resizes, repacks or changes the texture/pixels/sampler state.
export class RendererTexturePreparation{
 constructor(renderer,work){this.renderer=renderer;this.work=work;this.prepared=new WeakMap();this.stats={uploaded:0,reused:0,deferred:0,failed:0,cancelled:0};}
 prepare(textures,{priority=1,current=()=>true}={}){
  const jobs=[];for(const texture of new Set(textures)){
   if(!texture?.isTexture||texture.isRenderTargetTexture||texture.onUpdate){this.stats.deferred++;continue;}
   const version=texture.version,sourceVersion=texture.source?.version;let record=this.prepared.get(texture);
   if(record?.version===version&&record.sourceVersion===sourceVersion){this.stats.reused++;jobs.push(record.work);continue;}
   record={version,sourceVersion,work:null};this.prepared.set(texture,record);
   record.work=this.work.run(()=>{
    // A producer can install a callback or replace data while this is queued.
    // Preserve first-draw callback semantics by leaving those textures alone.
    if(texture.onUpdate||texture.isRenderTargetTexture){this.stats.deferred++;if(this.prepared.get(texture)===record)this.prepared.delete(texture);return false;}
    this.renderer.initTexture(texture);record.version=texture.version;record.sourceVersion=texture.source?.version;this.stats.uploaded++;return true;
   },{priority,kind:'texture',current}).catch(error=>{if(this.prepared.get(texture)===record)this.prepared.delete(texture);if(error.code==='FRAME_WORK_CLOSED'||error.code==='FRAME_WORK_CANCELLED')this.stats.cancelled++;else this.stats.failed++;throw error;});jobs.push(record.work);
  }return Promise.all(jobs);
 }
 snapshot(){return{...this.stats};}
}
