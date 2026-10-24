import {Group,Object3D,Material} from 'three';
import {observeRendererHierarchy} from './renderer_hierarchy.js';
import {isLocalRendererHook} from './renderer_local_hooks.js';
const ob=Object3D.prototype,mb=Material.prototype;
const drawable=o=>o.isMesh||o.isLine||o.isPoints||o.isSprite||o.isLight;

// EXPERIMENT: compile transform-only ancestry out of Three's main projection
// walk. Keep source objects, matrices, materials, sort order and parent links.
// The full authored hierarchy is restored for shadows and direct submission.
// Unknown draw callbacks use the ordinary path; known hooks only set uniforms.
// Nothing is attached/detached and no source resource is cloned or disposed.
export class RendererFlatScene {
 constructor(renderer){this.renderer=renderer;this.scene=null;this.hierarchy=null;this.revision=-1;this.records=[];this.groups=[];this.running=false;this.stats={};}
 compile(scene){
  if(this.scene!==scene){this.reset();this.scene=scene;this.hierarchy=observeRendererHierarchy(scene);}
  if(this.revision===this.hierarchy.revision)return;
  this.records=[];this.unsupported=null;
  const visit=(object,parent)=>{
   const index=this.records.length,record={object,parent,end:0,order:0};this.records.push(record);
   if(object.isLOD)this.unsupported='lod-subtree';
   for(const child of object.children)visit(child,index);
   record.end=this.records.length;
   // Empty transform-only leaves cannot influence a submitted object.
   if(record.end===index+1&&!drawable(object))this.records.pop();
  };
  visit(scene,-1);this.revision=this.hierarchy.revision;
 }
 prepare(scene,camera){
  this.compile(scene);if(this.unsupported)return null;
  const children=[];let used=0,lastOrder=null,group,subtreeUntil=-1;
  for(let i=0;i<this.records.length;i++){
   const r=this.records[i],o=r.object;
   if(!o.visible){i=r.end-1;continue;}
   const layer=o.layers.test(camera.layers);
   r.order=o.isGroup&&layer?o.renderOrder:r.parent<0?0:this.records[r.parent].order;
   if(!drawable(o)||!layer)continue;
   if(o.onAfterRender!==ob.onAfterRender||o.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(o.onBeforeRender))return null;
   for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){if(m.onBeforeRender!==mb.onBeforeRender)return null;}
   if(i<subtreeUntil)continue;
   if(lastOrder!==r.order){group=this.groups[used]??=new Group();used++;group.renderOrder=r.order;group.layers.mask=camera.layers.mask;group.matrixAutoUpdate=false;group.matrixWorldAutoUpdate=false;group.children=[];children.push(group);lastOrder=r.order;}
   group.children.push(o);
   // Preserve a drawable's own subtree as one unit: Three visits it normally,
   // so descendants must not also be emitted into the flat list.
   if(o.children.length)subtreeUntil=r.end;
  }
  this.stats={sourceNodes:this.hierarchy.nodes.length,compiledNodes:this.records.length,submittedObjects:children.reduce((n,g)=>n+g.children.length,0),groups:used};
  return children;
 }
 prepareMembership(objects,{scene,camera,hasLOD=false,lightSlotGroup=null}){this.preparedMembership={objects,scene,camera,hasLOD,lightSlotGroup};}
 prepareShared(scene,camera,prepared){
  if(prepared.hasLOD)return null;
  const children=[];let used=0,lastOrder=null,group,blocked=null;
  for(const o of prepared.objects){
   if(o.onAfterRender!==ob.onAfterRender||o.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(o.onBeforeRender))return null;
   for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])if(m.onBeforeRender!==mb.onBeforeRender)return null;
   if(o!==prepared.lightSlotGroup&&(!o.layers.test(camera.layers)||!drawable(o)))continue;
   if(blocked){let parent=o.parent,skip=false;while(parent){if(blocked.has(parent)){skip=true;break;}parent=parent.parent;}if(skip)continue;}
   let order=0;for(let node=o;node;node=node.parent)if(node.isGroup&&node.layers.test(camera.layers)){order=node.renderOrder;break;}
   if(lastOrder!==order){group=this.groups[used]??=new Group();used++;group.renderOrder=order;group.layers.mask=camera.layers.mask;group.matrixAutoUpdate=false;group.matrixWorldAutoUpdate=false;group.children=[];children.push(group);lastOrder=order;}
   group.children.push(o);if(o.children.length)(blocked??=new Set()).add(o);
  }
  this.stats={shared:true,membershipObjects:prepared.objects.length,submittedObjects:children.reduce((n,g)=>n+g.children.length,0),groups:used};return children;
 }
 render(scene,camera,draw){
  const prepared=this.preparedMembership;this.preparedMembership=null;
  if(this.running||scene.matrixWorldAutoUpdate!==false||scene.onBeforeRender!==ob.onBeforeRender||scene.onAfterRender!==ob.onAfterRender||camera.isArrayCamera||this.renderer.xr?.enabled){this.stats={fallback:'unsupported-pass'};return draw();}
  const shared=prepared?.scene===scene&&prepared.camera===camera,flattened=shared?this.prepareShared(scene,camera,prepared):this.prepare(scene,camera);if(!flattened){this.stats={fallback:this.unsupported??'render-callback'};return draw();}
  const originalChildren=scene.children,map=this.renderer.shadowMap,shadow=map.render,direct=this.renderer.renderBufferDirect;this.running=true;
  const restoreFor=callback=>{scene.children=originalChildren;try{return callback();}finally{scene.children=flattened;}};
  map.render=function(...args){return restoreFor(()=>shadow.apply(this,args));};
  this.renderer.renderBufferDirect=function(...args){return restoreFor(()=>direct.apply(this,args));};
  scene.children=flattened;
  try{return draw();}finally{scene.children=originalChildren;map.render=shadow;this.renderer.renderBufferDirect=direct;this.running=false;}
 }
 snapshot(){return {...this.stats};}
 reset(){this.preparedMembership=null;this.hierarchy?.release();this.hierarchy=null;this.scene=null;this.revision=-1;this.records=[];for(const g of this.groups)g.children=[];this.groups=[];this.stats={};this.unsupported=null;}
 dispose(){this.reset();}
}
