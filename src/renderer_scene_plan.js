import {Object3D} from 'three';
import {RendererSpatialVisibility} from './renderer_spatial_visibility.js';

// Experimental projection only. Three retains its own upload owners, render
// lists, sorting, shadow pass, draw callbacks and shader dispatch. A same-frame
// lighting membership handoff avoids projecting transform-only ancestry twice.
// Source parents/children are never edited. No GPU resources are owned here.
export class RendererScenePlan {
 constructor(renderer){this.renderer=renderer;this.enabled=false;this.spatialEnabled=false;this.spatial=new RendererSpatialVisibility();this.stats={};const owner=this;this.hook=function(scene,camera,state){return owner.project(scene,camera,state)||owner.previous?.(scene,camera,state)===true;};this.attach();this.restored=()=>{this.prepared=null;this.spatial.reset();this.attach();};renderer.domElement?.addEventListener('webglcontextrestored',this.restored);}
 attach(){if(this.api?.project===this.hook)this.api.project=this.previous;const api=this.renderer.nwnDrawAPI;this.api=api?.projectionVersion===1?api:null;this.previous=this.api?.project;if(this.api)this.api.project=this.hook;}
 prepareMembership(objects,info){this.prepared={objects,...info};}
 project(scene,camera,{list,state,objects,frustum,projection,vector}){
  const prepared=this.prepared;this.prepared=null;this.stats={enabled:this.enabled,projected:0,lights:0,shared:false};
  if(!this.enabled)return false;
  if(camera.isArrayCamera||this.renderer.xr.enabled||scene.onBeforeRender!==Object3D.prototype.onBeforeRender){this.stats.fallback='unsupported-pass';return false;}
  let members;
  if(prepared?.scene===scene&&prepared.camera===camera){if(prepared.hasLOD){this.stats.fallback='lod';return false;}members=prepared.objects;this.stats.shared=true;}
  else {members=[];let lod=false;scene.traverseVisible(o=>{if(o.isLOD)lod=true;if(o.isLight||o.isMesh||o.isLine||o.isPoints||o.isSprite)members.push(o);});if(lod){this.stats.fallback='lod';return false;}}
  if(this.spatialEnabled){this.spatial.prepare(members,frustum);this.stats.spatial=this.spatial.snapshot();}
  const push=(o,geometry,material,order,z,group)=>{if(material?.visible){list.push(o,geometry,material,order,z,group);this.stats.projected++;}};
  const visit=o=>{
   if(!o.visible)return;
   if(o===prepared?.lightSlotGroup){for(const child of o.children)visit(child);return;}
   if(!o.layers.test(camera.layers))return;
   if(o.isLight){state.pushLight(o);if(o.castShadow)state.pushShadow(o);this.stats.lights++;return;}
   if(!(o.isSprite||o.isMesh||o.isLine||o.isPoints))return;
   if(this.spatialEnabled&&!this.spatial.accepts(o))return;
   if(o.frustumCulled&&!(o.isSprite?frustum.intersectsSprite(o):frustum.intersectsObject(o)))return;
   const geometry=objects.update(o),material=o.material;
   let order=0;for(let parent=o;parent;parent=parent.parent)if(parent.isGroup&&parent.layers.test(camera.layers)){order=parent.renderOrder;break;}
   if(this.renderer.sortObjects){
    if(o.isSprite)vector.setFromMatrixPosition(o.matrixWorld);
    else if(o.boundingSphere!==undefined){if(o.boundingSphere===null)o.computeBoundingSphere();vector.copy(o.boundingSphere.center).applyMatrix4(o.matrixWorld);}
    else {if(geometry.boundingSphere===null)geometry.computeBoundingSphere();vector.copy(geometry.boundingSphere.center).applyMatrix4(o.matrixWorld);}
    vector.applyMatrix4(projection);
   }
   if(Array.isArray(material))for(const group of geometry.groups)push(o,geometry,material[group.materialIndex],order,vector.z,group);
   else push(o,geometry,material,order,vector.z,null);
  };
  for(const object of members)visit(object);
  this.stats.members=members.length;return true;
 }
 snapshot(){return{...this.stats,enabled:this.enabled,bridge:this.api?.projectionVersion??null};}
 dispose(){if(this.api?.project===this.hook)this.api.project=this.previous;this.renderer.domElement?.removeEventListener('webglcontextrestored',this.restored);this.prepared=null;this.spatial.reset();this.enabled=false;this.stats={};}
}
