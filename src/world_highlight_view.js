import {Vector3} from 'three';
import {isTextEntry} from './game_input.js';
import {pointerRay} from './world_picking.js';
import {observeRendererHierarchy} from './renderer_hierarchy.js';
import {highlightEligible,highlightColor,highlightName,highlightNameColor,highlightNameValue} from './world_highlight.js';
import {WorldHighlightRenderer} from './world_highlight_renderer.js';

export class WorldHighlightView{
 constructor({viewport,canvas,camera,scene,context,enabled=()=>true,resolve=async value=>value?.text??'',details=async()=>({}),onHover=()=>{},report=()=>{}}){
  Object.assign(this,{viewport,canvas,camera,context,enabled,resolve,details,onHover,report});this.renderer=new WorldHighlightRenderer(scene);this.cache=new Map();this.labels=new Map();this.nameCache=new WeakMap();this.generation=0;this.tab=false;this.pointer=null;this.lastPick=-Infinity;
  this.host=document.createElement('div');this.host.className='world-highlight-labels';this.host.hidden=true;this.host.setAttribute('aria-hidden','true');viewport.append(this.host);
  this.abort=new AbortController();const signal=this.abort.signal;
  viewport.addEventListener('pointermove',e=>{this.pointer=e.target===canvas&&!e.buttons?{x:e.clientX,y:e.clientY}:null;this.dirty=true;if(!this.pointer)this.hover(null);},{capture:true,signal});
  canvas.addEventListener('pointerleave',()=>{this.pointer=null;this.hover(null);},{signal});
  canvas.addEventListener('pointerdown',()=>{this.pointer=null;this.hover(null);},{signal});
  canvas.addEventListener('pointerup',e=>{this.pointer={x:e.clientX,y:e.clientY};this.dirty=true;},{signal});
  window.addEventListener('keydown',e=>{if(e.key!=='Tab'||e.defaultPrevented||e.ctrlKey||e.altKey||e.metaKey||isTextEntry(e.target)||!this.context()||!this.enabled())return;e.preventDefault();this.tab=true;},{capture:true,signal});
  window.addEventListener('keyup',e=>{if(e.key==='Tab'){if(this.tab)e.preventDefault();this.tab=false;}},{capture:true,signal});
  window.addEventListener('blur',()=>this.release(),{signal});
  document.addEventListener('visibilitychange',()=>{if(document.hidden)this.release();},{signal});
  document.addEventListener('focusin',e=>{if(isTextEntry(e.target))this.release();},{signal});
 }
 hover(object){if(this.hovered===object)return;this.hovered=object;this.onHover(object);}
 release(){this.tab=false;this.pointer=null;this.hover(null);this.renderer.clear();if(!this.host.hidden)this.host.hidden=true;const state=JSON.stringify({hovered:null,tab:false,objects:[],parts:0,draws:0});if(this.canvas.dataset.worldHighlights!==state)this.canvas.dataset.worldHighlights=state;}
 reset(){this.release();this.generation++;this.hierarchy?.release();this.hierarchy=null;this.owner=null;this.cache.clear();this.nameCache=new WeakMap();this.labels.clear();this.host.replaceChildren();delete this.canvas.dataset.worldHighlights;}
 entries(context){
  if(!this.tab)return this.hovered?[this.hovered]:[];
  return[...context.objects.values()].filter(o=>highlightEligible(o,context));
 }
 meshes(root){
  let record=this.cache.get(root);if(record?.revision!==this.hierarchy.revision){const meshes=[];root.traverse(mesh=>{if(mesh.isMesh&&mesh.userData.nativeModelMesh)meshes.push(mesh);});record={revision:this.hierarchy.revision,meshes};this.cache.set(root,record);}return record.meshes;
 }
 label(entry,context){
  const object=entry.object,value=highlightNameValue(object),s=object.replicated??{},signature=JSON.stringify([context.textVersion??0,value,s.damageLevel,s.hitPoints,s.portrait,s.portraitRef]);let cached=this.nameCache.get(object);
  if(cached?.signature!==signature){
   cached={signature,text:''};this.nameCache.set(object,cached);const generation=this.generation;
   void highlightName(value,v=>this.resolve(v,context,object)).then(text=>{if(this.generation===generation&&this.nameCache.get(object)===cached)cached.text=text;}).catch(error=>{if(this.generation===generation)this.report(error);});
   if(object.objectType===5)void Promise.resolve().then(()=>this.details(object,context)).then(info=>{if(this.generation===generation&&this.nameCache.get(object)===cached)cached.info=info;}).catch(error=>{if(this.generation===generation)this.report(error);});
  }
  let label=this.labels.get(object.id);if(!label){label=document.createElement('div');label.className='world-highlight-label';label.dataset.objectId=String(object.id);const portrait=document.createElement('img'),name=document.createElement('span'),condition=document.createElement('span');portrait.className='world-highlight-portrait';portrait.alt='';name.className='world-highlight-name';condition.className='world-highlight-condition';label.append(portrait,name,condition);this.labels.set(object.id,label);this.host.append(label);}
  const [portrait,name,condition]=label.children;if(name.textContent!==cached.text)name.textContent=cached.text;name.style.color=highlightNameColor(object,context.playerId);const status=cached.info?.condition??'';if(condition.textContent!==status)condition.textContent=status;condition.style.color=['#80ff40','#80ff40','#ffff40','#ffad40','#ff5555','#aaa'][cached.info?.level]??'#80ff40';
  if(cached.info?.portrait){if(portrait.getAttribute('src')!==cached.info.portrait)portrait.src=cached.info.portrait;if(portrait.hidden)portrait.hidden=false;}else{if(portrait.hasAttribute('src'))portrait.removeAttribute('src');const hidden=object.objectType!==5;if(portrait.hidden!==hidden)portrait.hidden=hidden;}
  return label;
 }
 update(time=performance.now()){
  const context=this.context();
  if(!context||!this.enabled()||document.hidden){if(this.owner)this.reset();return;}
  if(this.owner!==context.identity||this.areaId!==context.areaId){this.reset();this.owner=context.identity;this.areaId=context.areaId;this.hierarchy=observeRendererHierarchy(context.root);this.lastPick=-Infinity;}
  if(isTextEntry(document.activeElement)){this.release();return;}
  if(this.pointer&&time-this.lastPick>=(this.dirty?50:100)){
   this.dirty=false;this.lastPick=time;
   if(document.elementFromPoint(this.pointer.x,this.pointer.y)!==this.canvas)this.hover(null);
   else{this.camera.updateMatrixWorld();const hit=context.pick(pointerRay(this.pointer.x,this.pointer.y,this.canvas.getBoundingClientRect(),this.camera));this.hover(highlightEligible(hit?.object,context)?hit.object:null);}
  }
  if(this.hovered&&(context.objects.get(this.hovered.id)!==this.hovered||!highlightEligible(this.hovered,context)))this.hover(null);
  const selected=this.entries(context),entries=[],usedRoots=new Set();
  for(const object of selected){const root=context.render(object.id);if(!root?.parent)continue;entries.push({object,root,meshes:this.meshes(root),color:highlightColor(object,context.playerId)});usedRoots.add(root);}
  for(const root of this.cache.keys())if(!usedRoots.has(root))this.cache.delete(root);
  this.renderer.update(entries,time);if(this.host.hidden!==!entries.length)this.host.hidden=!entries.length;
  if(entries.length){
   this.camera.updateMatrixWorld();const bounds=this.canvas.getBoundingClientRect(),host=this.host.getBoundingClientRect(),position=new Vector3(),active=new Set();
   for(const entry of entries){
    if(entry.bounds.isEmpty()||entry.object.objectType!==5&&entry.object!==this.hovered)continue;const label=this.label(entry,context);active.add(entry.object.id);entry.bounds.getCenter(position);position.y=entry.bounds.max.y+.15;position.project(this.camera);
    const hidden=position.z< -1||position.z>1||Math.abs(position.x)>1||Math.abs(position.y)>1;if(label.hidden!==hidden)label.hidden=hidden;
    label.style.left=(bounds.left-host.left+(position.x+1)*bounds.width/2)+'px';label.style.top=(bounds.top-host.top+(1-position.y)*bounds.height/2)+'px';
   }
   for(const [id,label]of this.labels)if(!active.has(id)){label.remove();this.labels.delete(id);}
  }else if(this.labels.size){this.labels.clear();this.host.replaceChildren();}
  const state=JSON.stringify({hovered:this.hovered?.id??null,tab:this.tab,objects:entries.filter(e=>!e.bounds.isEmpty()).map(e=>e.object.id),parts:this.renderer.parts,draws:this.renderer.parts?1:0});if(this.canvas.dataset.worldHighlights!==state)this.canvas.dataset.worldHighlights=state;
 }
 dispose(){this.reset();this.abort.abort();this.renderer.dispose();this.host.remove();}
}
