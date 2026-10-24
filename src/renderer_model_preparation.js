import {Scene,Group,InstancedMesh,MeshDepthMaterial,MeshDistanceMaterial,RGBADepthPacking,WebGLRenderTarget,VSMShadowMap,FrontSide,BackSide} from 'three';
import {createShadowInstanceMaterial} from './renderer_shadow_instances.js';
import {RendererProgramCache} from './renderer_program_cache.js';
const unprepared=Symbol('unprepared');

// GPU cache templates only: no animation, particles, native object IDs or RNG.
// Keep their materials alive until resource release: disposing them immediately
// would release the linked programs before the real instance can reuse them.
export class RendererModelPreparation{
 constructor({renderer,scene,camera,createRoot,destroyRoot,profile=()=>'',report=()=>{},shadowInstances=false,cachePrograms=false,programLimit=128}){
  Object.assign(this,{renderer,scene,camera,createRoot,destroyRoot,profile,report,shadowInstances});
  this.records=new Map();this.areas=new Map();this.closed=false;this.shadowTarget=new WebGLRenderTarget(1,1);
  // WebGLShadowMap draws with an empty scene, while keeping the main render
  // state's lights. Fog contributes to Three's cache key even for depth
  // materials that do not use fog. Match both inputs without mutating the live
  // scene during callbacks or retaining a second copy of its object hierarchy.
  this.shadowScene=new Scene();this.shadowScene.traverseVisible=callback=>this.scene.traverseVisible(callback);
  this.programCache=cachePrograms?new RendererProgramCache(renderer,{maxPrograms:programLimit}):null;
  this.stats={templates:0,compilations:0,pending:0,destroyed:0,failed:0,skipped:0,profileScans:0,profileMs:0,batches:0,compileCalls:0,last:null};
 }
 prepareArea(root,{current=()=>true}={}){
  if(this.closed||!current())return Promise.resolve(false);
  if(this.areas.has(root)){if(this.areas.get(root).cacheEpoch===this.programCache?.epoch)return this.areas.get(root).work;this.releaseArea(root);}
  const record={name:root.name,root:null,colors:null,fades:null,shadows:null,retired:false,destroyed:false,work:null,cacheEpoch:this.programCache?.epoch};this.areas.set(root,record);
  record.work=Promise.resolve().then(async()=>{
   if(record.retired||this.closed||!current())return false;
   this.stats.pending++;const started=performance.now();
   try{
    record.colors=this.materialRoot(root);record.fades=this.fadeRoot(root);record.shadows=this.shadowRoot(root);
    const jobs=[];try{
     // Three's asynchronous compiler polls material.currentProgram later.
     // Live particle/keyhole/object updates can replace or dispose that handle.
     // Own every polled material until completion, as for fade/shadow variants;
     // leave lights solely in the target scene so they are counted once.
     jobs.push(this.renderer.compileAsync(record.colors,this.camera,this.scene));
     jobs.push(this.renderer.compileAsync(record.fades,this.camera,this.scene));
     if(record.shadows.children.length)jobs.push(this.compileShadows(record.shadows));
    }catch(error){jobs.push(Promise.reject(error));}
    const results=await Promise.allSettled(jobs),failure=results.find(r=>r.status==='rejected');if(failure)throw failure.reason;
    if(record.retired||this.closed||!current())return false;
    record.ready=true;this.report('renderer.area-variants-prepared','Area color, fade and shadow programs prepared together',{name:record.name,durationMs:performance.now()-started});return true;
   }catch(error){this.stats.failed++;throw error;}finally{this.stats.pending--;}
  });return record.work;
 }
 releaseArea(root){
  const record=this.areas.get(root);if(!record)return;this.areas.delete(root);record.retired=true;
  void record.work.finally(()=>this.destroy(record)).catch(error=>this.report('renderer.area-preparation-cleanup-failed',error.message,{name:record.name}));
 }
 prepare(asset,name,{current=()=>true}={}){
  if(this.closed||!current()){this.stats.skipped++;return Promise.resolve(false);}
  let record=this.records.get(asset);
  if(!record){record={name,root:null,shadows:null,fades:null,work:Promise.resolve(),retired:false,destroyed:false,prepared:unprepared};this.records.set(asset,record);}
  // Serialize uses of the same materials; different resources can compile in
  // parallel. A profile change must not replace a program a prior poll is using.
  const work=record.work.then(async()=>{
   if(record.retired||this.closed||!current())return false;
   const profile=this.readProfile();if(record.prepared===profile&&record.cacheEpoch===this.programCache?.epoch)return true;record.cacheEpoch=this.programCache?.epoch;record.ready=false;
   const started=performance.now();this.stats.pending++;
   const hidden=[],phases=[];
   try{
    if(!record.root){record.root=this.createRoot(asset,name);record.root.userData.rendererOnlyPreparation=true;record.shadows=this.shadowRoot(record.root);record.fades=this.fadeRoot(record.root);this.stats.templates++;}
    // The template must not add lights to compileAsync's target-scene counts.
    // Actual scene light/shadow admission remains owned by its existing helpers.
    record.root.traverse(o=>{if(o.isLight){hidden.push([o,o.visible]);o.visible=false;}});
    // Independent materials let the driver prepare all variants concurrently;
    // toggling the source material would replace handles a prior poll is using.
    const jobs=[],start=(kind,root)=>{const at=performance.now();this.stats.compileCalls++;const work=kind==='shadow'?this.compileShadows(root):this.renderer.compileAsync(root,this.camera,this.scene);jobs.push(Promise.resolve(work).finally(()=>phases.push({kind,durationMs:performance.now()-at})));};
    try{
     start('color',record.root);start('fade',record.fades);
     if(record.shadows.children.length){
      // Starting compilation captures the linear shadow output profile. Put
      // back the ordinary target synchronously before any polling can yield.
      start('shadow',record.shadows);
     }
    }catch(error){jobs.push(Promise.reject(error));}
    // Even a failed/superseded owner must retain every still-polled material.
    const settled=await Promise.allSettled(jobs),failed=settled.find(r=>r.status==='rejected');if(failed)throw failed.reason;
    if(record.retired||this.closed||!current())return false;
    record.prepared=profile;record.ready=true;this.stats.compilations++;
    const durationMs=performance.now()-started;this.stats.last={name,durationMs,profile,phases};
    if(durationMs>100)this.report('renderer.asset-shaders-prepared','GPU resource shaders prepared before model instantiation',{name,durationMs,profile,phases});
    return true;
   }catch(error){
    this.stats.failed++;this.report('renderer.asset-preparation-failed',error.message,{name});throw error;
   }finally{for(const [light,visible]of hidden)light.visible=visible;this.stats.pending--;}
  });
  record.work=work.catch(()=>{});return work;
 }
 readProfile(){const at=performance.now();this.stats.profileScans++;try{return this.profile();}finally{this.stats.profileMs+=performance.now()-at;}}
 prepareBatch(entries,{current=()=>true}={}){
  if(this.closed||!current()){this.stats.skipped+=entries.length;return Promise.resolve(false);}
  const assets=new Map(),records=[...new Map(entries.map(({asset,name})=>{
   let record=this.records.get(asset);
   if(!record){record={name,root:null,shadows:null,fades:null,work:Promise.resolve(),retired:false,destroyed:false,prepared:unprepared};this.records.set(asset,record);}
   assets.set(record,asset);return[asset,record];
  })).values()];
  if(!records.length)return Promise.resolve(true);
  // Reserve every record before waiting. Both single-asset and overlapping
  // batches then serialize each polled material's ownership without deadlock.
  const work=Promise.all(records.map(record=>record.work)).then(async()=>{
   if(this.closed||!current()){this.stats.skipped+=records.length;return false;}
   const live=records.filter(record=>!record.retired);if(!live.length)return false;const profile=this.readProfile(),pending=live.filter(record=>record.prepared!==profile||record.cacheEpoch!==this.programCache?.epoch);
   if(!pending.length)return live.length===records.length;
   this.stats.pending+=pending.length;this.stats.batches++;const started=performance.now(),hidden=[],phases=[],colors=new Group(),fades=new Group(),shadows=new Group();
   try{
    for(const record of pending){
     record.cacheEpoch=this.programCache?.epoch;record.ready=false;
     if(!record.root){record.root=this.createRoot(assets.get(record),record.name);record.root.userData.rendererOnlyPreparation=true;record.shadows=this.shadowRoot(record.root);record.fades=this.fadeRoot(record.root);this.stats.templates++;}
     record.root.traverse(object=>{if(object.isLight){hidden.push([object,object.visible]);object.visible=false;}});
     colors.add(record.root);fades.add(record.fades);shadows.add(record.shadows);
    }
    const jobs=[],start=(kind,root)=>{const at=performance.now();this.stats.compileCalls++;const job=kind==='shadow'?this.compileShadows(root):this.renderer.compileAsync(root,this.camera,this.scene);jobs.push(Promise.resolve(job).finally(()=>phases.push({kind,durationMs:performance.now()-at})));};
    try{
     start('color',colors);start('fade',fades);
     if(shadows.children.some(root=>root.children.length))start('shadow',shadows);
    }catch(error){jobs.push(Promise.reject(error));}
    const results=await Promise.allSettled(jobs),failure=results.find(result=>result.status==='rejected');if(failure)throw failure.reason;
    if(this.closed||!current())return false;
    for(const record of pending)if(!record.retired){record.prepared=profile;record.ready=true;this.stats.compilations++;}
    const durationMs=performance.now()-started;this.stats.last={names:pending.map(record=>record.name),durationMs,profile,phases};
    if(durationMs>100)this.report('renderer.asset-batch-shaders-prepared','Multipart resource shaders prepared in one scene profile',{assets:pending.length,durationMs,profile,phases});
    return live.length===records.length&&!pending.some(record=>record.retired);
   }catch(error){this.stats.failed+=pending.length;this.report('renderer.asset-batch-preparation-failed',error.message,{assets:pending.length});throw error;}
   finally{
    // compileAsync can still poll every submitted material after one job
    // rejects. All jobs above settle before roots detach or release can run.
    colors.clear();fades.clear();shadows.clear();for(const [light,visible]of hidden)light.visible=visible;this.stats.pending-=pending.length;
   }
  });
  const settled=work.catch(()=>{});for(const record of records)record.work=settled;return work;
 }
 compileShadows(root){const target=this.renderer.getRenderTarget();try{this.renderer.setRenderTarget(this.shadowTarget);return this.renderer.compileAsync(root,this.camera,this.shadowScene);}finally{this.renderer.setRenderTarget(target);}}
 materialRoot(root,{fade=false}={}){
  const batch=new Group(),materials=new Map();
  root.traverse(object=>{
   if(!object.material)return;
   const original=Array.isArray(object.material)?object.material:[object.material],warm=original.map(material=>{
    let copy=materials.get(material);if(!copy){copy=material.clone();copy.onBeforeCompile=material.onBeforeCompile;copy.customProgramCacheKey=material.customProgramCacheKey;if(fade)copy.transparent=!material.transparent;materials.set(material,copy);}return copy;
   });
   const copy=object.clone(false);copy.material=Array.isArray(object.material)?warm:warm[0];batch.add(copy);
  });return batch;
 }
 fadeRoot(root){return this.materialRoot(root,{fade:true});}
 shadowRoot(root){
  const batch=new Group(),materials=new Map(),instanceMaterials=new Map();
  root.traverse(mesh=>{
   if(!mesh.isMesh||!mesh.castShadow||!mesh.material)return;
   for(const point of [false,true]){
    const original=Array.isArray(mesh.material)?mesh.material:[mesh.material],warm=original.map(material=>{
     const custom=point?mesh.customDistanceMaterial:mesh.customDepthMaterial,key=custom??material;
     let pair=materials.get(key);if(!pair)materials.set(key,pair=[]);
     if(pair[Number(point)])return pair[Number(point)];
     const result=custom?custom.clone():point?new MeshDistanceMaterial():new MeshDepthMaterial({depthPacking:RGBADepthPacking});
     if(custom){result.onBeforeCompile=custom.onBeforeCompile;result.customProgramCacheKey=custom.customProgramCacheKey;}
     // WebGLShadowMap.getDepthMaterial copies these fields into its own
     // depth/distance variants. This prepares that renderer path, not NWN AI.
     result.visible=material.visible;result.wireframe=material.wireframe;
     result.side=material.shadowSide??(this.renderer.shadowMap.type===VSMShadowMap?material.side:material.side===FrontSide?BackSide:material.side===BackSide?FrontSide:material.side);
     result.alphaMap=material.alphaMap;result.alphaTest=material.alphaToCoverage ? 0.5 : material.alphaTest;result.map=material.map;
     result.clipShadows=material.clipShadows;result.clippingPlanes=material.clippingPlanes;result.clipIntersection=material.clipIntersection;
     result.displacementMap=material.displacementMap;result.displacementScale=material.displacementScale;result.displacementBias=material.displacementBias;
     result.wireframeLinewidth=material.wireframeLinewidth;result.linewidth=material.linewidth;
     pair[Number(point)]=result;return result;
    });
    const copy=mesh.clone(false);copy.material=Array.isArray(mesh.material)?warm:warm[0];batch.add(copy);
    // The live shadow adapter uses a different vertex program for rigid
    // instances. Prepare that exact hook AND InstancedMesh feature flag before
    // its first shadow draw. These compile-only objects allocate no GPU VBOs,
    // never join the live scene, and borrow the source geometry/texture owners.
    if(this.shadowInstances&&this.renderer.shadowMap.type!==VSMShadowMap&&!mesh.isSkinnedMesh&&!mesh.isInstancedMesh&&!mesh.isBatchedMesh&&!Array.isArray(mesh.material)&&!mesh.customDepthMaterial&&!mesh.customDistanceMaterial){
     let material=instanceMaterials.get(warm[0]);if(!material){material=createShadowInstanceMaterial(point);material.copy(warm[0]);instanceMaterials.set(warm[0],material);}
     const instance=new InstancedMesh(mesh.geometry,material,1);batch.add(instance);
    }
   }
  });return batch;
 }
 release(asset){
  const record=this.records.get(asset);if(!record)return;
  this.records.delete(asset);record.retired=true;
  // compileAsync still polls these material handles. Teardown retires them now
  // and destroys them once that poll finishes; no stale template can attach.
  void record.work.finally(()=>this.destroy(record)).catch(error=>this.report('renderer.asset-preparation-cleanup-failed',error.message,{name:record.name}));
 }
 destroy(record){
  if(record.destroyed)return;record.destroyed=true;
  const materials=new Set();for(const root of [record.colors,record.shadows,record.fades])root?.traverse(o=>{if(o.isInstancedMesh)o.dispose();for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])materials.add(m);});
  for(const material of materials)if(this.closed||!record.ready||!this.programCache?.adopt(material,record.cacheEpoch))material.dispose();record.colors?.clear();record.shadows?.clear();record.fades?.clear();
  // Shadow clones share the template's geometry; destroyRoot owns it once.
  if(record.root){this.destroyRoot(record.root);this.stats.destroyed++;}
  record.root=null;record.colors=null;record.shadows=null;record.fades=null;
 }
 resetPrograms(){this.programCache?.clear();}
 snapshot(){return{...this.stats,activeTemplates:this.records.size,activeAreas:this.areas.size,programCache:this.programCache?.snapshot()??null};}
 dispose(){if(this.closed)return;this.closed=true;this.programCache?.dispose();for(const asset of [...this.records.keys()])this.release(asset);for(const root of [...this.areas.keys()])this.releaseArea(root);this.shadowTarget.dispose();}
}
