import {Scene,Sphere,Vector3,VSMShadowMap,Object3D} from 'three';
import {RendererPointShadowCache} from './renderer_point_shadow_cache.js';
import {RendererShadowInstances} from './renderer_shadow_instances.js';

// Three walks the complete scene for each of a point shadow's six faces. Give
// that same renderer a conservative, flat list of nearby casters instead. The
// objects retain their real parents, matrices, materials, hooks and identities;
// Three still performs the final face-frustum test and all shadow drawing.
// This is a renderer adapter, not a change to native light/shadow admission.
export class RendererShadowTraversal{
 constructor(renderer,{instances=false}={}){
  this.renderer=renderer;this.shadowMap=renderer.shadowMap;this.original=this.shadowMap.render;this.proxy=new Scene();this.position=new Vector3();this.type=null;this.state=null;this.cache=new RendererPointShadowCache(renderer.domElement);
  this.instances=instances?new RendererShadowInstances(renderer):null;
  this.wrapper=(lights,scene,camera)=>this.render(lights,scene,camera);this.shadowMap.render=this.wrapper;
  // Retire external VBO registrations while the old context is lost, before
  // Three creates a new attributes owner. Deleting those old-context handles
  // after restoration would produce INVALID_OPERATION in WebGL.
  this.lostHook=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lostHook);
  this.restoreHook=()=>{if(this.shadowMap.render===this.wrapper)this.shadowMap.render=this.original;this.shadowMap=renderer.shadowMap;this.original=this.shadowMap.render;this.shadowMap.render=this.wrapper;this.type=null;this.state=null;this.instances?.reset();};renderer.domElement?.addEventListener('webglcontextrestored',this.restoreHook);
 }
 render(lights,scene,camera){
  const prepared=this.preparedMembership;this.preparedMembership=null;
  const map=this.shadowMap;
  const callsBefore=this.renderer.info?.render.calls??0,trianglesBefore=this.renderer.info?.render.triangles??0;
  if(!map.enabled||!map.autoUpdate&&!map.needsUpdate||!lights.length){this.state={skipped:true,drawCalls:0,triangles:0};return this.original.call(map,lights,scene,camera);}
  // Type changes are one whole-render operation in Three (not per light).
  // Keep that path and VSM's receiver/blur path completely unchanged.
  if(this.type!==map.type||map.type===VSMShadowMap){this.type=map.type;const result=this.original.call(map,lights,scene,camera);this.state={fallback:true,drawCalls:(this.renderer.info?.render.calls??0)-callsBefore,triangles:(this.renderer.info?.render.triangles??0)-trianglesBefore};return result;}
  this.cache.begin();this.prefixCache?.begin();const entries=[];let visited=0;
  const collect=object=>{
   visited++;if(!object.visible)return;
   const renderable=object.isMesh||object.isLine||object.isPoints;
   // Preserve unusual renderable subtrees as a unit, without duplicate draws
   // or temporarily editing the live object's children for a shadow pass.
   if(renderable&&object.children.length){entries.push({object,sphere:null});return;}
   if(renderable&&object.castShadow&&object.layers.test(camera.layers)){
    let sphere=null;
    if(object.frustumCulled){
     if(object.boundingSphere!==undefined){if(object.boundingSphere===null)object.computeBoundingSphere();sphere=object.boundingSphere;}
     else if(object.geometry){if(object.geometry.boundingSphere===null)object.geometry.computeBoundingSphere();sphere=object.geometry.boundingSphere;}
     if(sphere)sphere=new Sphere().copy(sphere).applyMatrix4(object.matrixWorld);
    }
    entries.push({object,sphere});
   }
   for(const child of object.children)collect(child);
  };
  const shared=this.reuseMembership&&prepared?.scene===scene&&prepared.camera===camera&&!prepared.hasLOD&&!camera.isArrayCamera&&scene.onBeforeRender===Object3D.prototype.onBeforeRender&&scene.onAfterRender===Object3D.prototype.onAfterRender;
  if(shared){
   let blocked=null;
   for(const object of prepared.objects){
    if(blocked){let parent=object.parent,skip=false;while(parent){if(blocked.has(parent)){skip=true;break;}parent=parent.parent;}if(skip)continue;}
    visited++;const renderable=object.isMesh||object.isLine||object.isPoints;
    if(renderable&&object.children.length){(blocked??=new Set()).add(object);entries.push({object,sphere:null});continue;}
    if(!renderable||!object.castShadow||!object.layers.test(camera.layers))continue;
    let sphere=null;if(object.frustumCulled){if(object.boundingSphere!==undefined){if(object.boundingSphere===null)object.computeBoundingSphere();sphere=object.boundingSphere;}else if(object.geometry){if(object.geometry.boundingSphere===null)object.geometry.computeBoundingSphere();sphere=object.geometry.boundingSphere;}if(sphere)sphere=new Sphere().copy(sphere).applyMatrix4(object.matrixWorld);}entries.push({object,sphere});
   }
  }else collect(scene);
  // Cached lights need no instance keys or buffers. Build keys only for the
  // caster lists that actually reach a shadow draw, retaining light order.
  const instances=this.renderer.clippingPlanes?.length?null:this.instances;instances?.begin(entries,{lazy:true});
  const requested=map.needsUpdate;let admitted=0,tests=0,fallbackLights=0,reusedLights=0,renderedLights=0,completed=false;
  try{
   for(const light of lights){
    if(light.shadow?.autoUpdate===false&&!light.shadow.needsUpdate)continue;
    map.needsUpdate=requested;
    const far=light.distance||light.shadow?.camera.far;
    if(!light.isPointLight||!(far>0)||!Number.isFinite(far)){fallbackLights++;if(instances){this.proxy.children=instances.list(entries,light);this.original.call(map,[light],this.proxy,camera);}else this.original.call(map,[light],scene,camera);continue;}
    this.position.setFromMatrixPosition(light.matrixWorld);const margin=far*1e-6+1e-6;
    const selected=entries.filter(entry=>{
     tests++;const s=entry.sphere;if(!s||!Number.isFinite(s.radius))return true;
     const extent=far+s.radius+margin;
     return Math.abs(s.center.x-this.position.x)<=extent&&Math.abs(s.center.y-this.position.y)<=extent&&Math.abs(s.center.z-this.position.z)<=extent;
    });this.proxy.children=selected.map(entry=>entry.object);
    admitted+=this.proxy.children.length;
    const plan=this.cache.plan(light,this.proxy.children,map.type,{force:requested||light.shadow.needsUpdate||Boolean(this.renderer.clippingPlanes?.length)});
    if(plan.reuse){reusedLights++;continue;}
    if(instances)this.proxy.children=instances.list(selected,light);
    if(this.prefixCache?.enabled){
     const shadowObjects=this.proxy.children;
     if(this.prefixCache.render(light,shadowObjects,map.type,this.cache,objects=>{this.proxy.children=objects;this.original.call(map,[light],this.proxy,camera);},object=>instances?.sourcesFor?.(object))){renderedLights++;this.cache.commit(light,plan,map.type);continue;}
     this.proxy.children=shadowObjects;
    }
    this.original.call(map,[light],this.proxy,camera);
    renderedLights++;this.cache.commit(light,plan,map.type);
   }
   completed=true;
  }finally{this.proxy.children=[];instances?.end();map.needsUpdate=completed?false:requested;this.state={membership:shared?'prepared':'hierarchy',visited,casters:entries.length,lights:lights.length,tests,admitted,fallbackLights,reusedLights,renderedLights,drawCalls:(this.renderer.info?.render.calls??0)-callsBefore,triangles:(this.renderer.info?.render.triangles??0)-trianglesBefore,instances:instances?.snapshot()??null};}
 }
 prepareMembership(objects,{scene,camera,hasLOD=false}){this.preparedMembership={objects,scene,camera,hasLOD};}
 snapshot(){return this.state?{...this.state,instances:this.instances?.snapshot()??null,prefix:this.prefixCache?.snapshot()??null}:null;}
 reset(){this.preparedMembership=null;this.instances?.reset();this.prefixCache?.reset();this.cache.restore();this.state=null;}
 dispose(){this.preparedMembership=null;if(this.shadowMap.render===this.wrapper)this.shadowMap.render=this.original;this.renderer.domElement?.removeEventListener('webglcontextrestored',this.restoreHook);this.renderer.domElement?.removeEventListener('webglcontextlost',this.lostHook);this.proxy.children=[];this.cache.dispose();this.instances?.dispose();this.prefixCache?.dispose();}
}
