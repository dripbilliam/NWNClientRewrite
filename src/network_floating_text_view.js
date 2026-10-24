import * as THREE from 'three';
import {createFloatingTextState,updateFloatingText} from './client_floating_text.js';
import {NativeBitmapFont} from './native_bitmap_font.js';
import {nativeRichText} from './native_rich_text.js';
export class NetworkFloatingTextView{
 constructor(viewport,{world,scene,camera,canvas,getResource,report}){Object.assign(this,{viewport,world,scene,camera,canvas,getResource,report});this.host=document.createElement('div');this.host.className='network-floating-text';this.host.style.cssText='position:absolute;inset:0;pointer-events:none;overflow:hidden;z-index:5';viewport.append(this.host);this.generation=0;this.entries=[];this.fonts=new Map();this.events=[];}
 reset(){this.generation++;this.entries=[];this.events=[];this.fonts.clear();this.host.replaceChildren();this.publish();}
 font(name){name=name||'fnt_galahad14';if(!this.fonts.has(name))this.fonts.set(name,NativeBitmapFont.load(this.getResource,name));return this.fonts.get(name);}
 warm(){const generation=this.generation;for(const font of ['fnt_floaty_smal','fnt_galahad14'])void this.font(font).catch(error=>{if(generation===this.generation)this.report('network.floating-font-failed',error.message,{font});});}
 add(event){
  const generation=this.generation,world=this.world(),areaId=world?.areaId;if(!world)return;const state=createFloatingTextState(event),entry={state,world,areaId,position:null,opacity:1,node:null};this.entries.push(entry);this.events.push({kind:'create',objectId:event.objectId,font:event.font,raw:event.raw});if(this.events.length>64)this.events.shift();
  void this.font(event.font).then(font=>{if(generation!==this.generation||!this.entries.includes(entry)||world!==this.world()||areaId!==world.areaId)return;const color='#'+event.rgb.map(v=>Math.round(Math.max(0,Math.min(1,v))*255).toString(16).padStart(2,'0')).join(''),spans=nativeRichText(event.raw).spans,rendered=font.render(spans,color);entry.node=rendered.canvas;entry.baseline=rendered.baseline;const style='position:absolute;image-rendering:pixelated;transform:translateX(-50%)';if(entry.state.shadow){entry.shadow=font.render(spans.map(s=>({...s,color:'#000000'})),'#000000').canvas;entry.shadow.style.cssText=style;entry.shadow.hidden=true;this.host.append(entry.shadow);}entry.node.style.cssText=style;entry.node.dataset.objectId=String(event.objectId);entry.node.setAttribute('aria-label',nativeRichText(event.raw).text);entry.node.hidden=true;this.host.append(entry.node);if(rendered.missing)this.report('network.floating-glyph-unavailable','Native bitmap font has no glyph for some text bytes',{font:event.font,count:rendered.missing});}).catch(error=>{if(generation===this.generation)this.report('network.floating-font-failed',error.message,{font:event.font});});
  this.publish();
 }
 update(delta){
  const scene=this.scene(),world=this.world(),camera=this.camera(),canvas=this.canvas();if(!world||!scene||!camera||!canvas)return;
  if(!this.entries.length)return;camera.updateMatrixWorld();const bounds=canvas.getBoundingClientRect(),host=this.host.getBoundingClientRect(),position=new THREE.Vector3();
  for(const entry of [...this.entries]){
   if(entry.world!==world||entry.areaId!==world.areaId){this.remove(entry);continue;}
   let visible=entry.visible??false;
   try{updateFloatingText(entry.state,delta,{destroy:()=>this.remove(entry),object:id=>{const o=world.registry.get(id);return o&&!o.replicationRemoved&&o.areaId===world.areaId?o:null;},model:o=>scene.objects.get(o.id)?.wrapper,world:()=>scene,
    position:model=>{model.getWorldPosition(position);return[position.x,-position.z,position.y];},project:(_scene,p)=>{position.set(p[0],p[2],-p[1]).project(camera);visible=position.z>=-1&&position.z<=1;return[(position.x+1)*bounds.width/2+bounds.left-host.left,(1-position.y)*bounds.height/2+bounds.top-host.top];},color:(which,_r,_g,_b,alpha)=>{if(which==='foreground')entry.opacity=alpha;},screen:p=>entry.position=p});
    entry.visible=visible;if(entry.node){entry.node.hidden=!visible;if(entry.position){entry.node.style.left=entry.position[0]+'px';entry.node.style.top=(entry.position[1]-entry.baseline)+'px';entry.node.style.opacity=entry.opacity;}if(entry.shadow){entry.shadow.hidden=!visible;if(entry.position){entry.shadow.style.left=(entry.position[0]-1)+'px';entry.shadow.style.top=(entry.position[1]-entry.baseline-1)+'px';entry.shadow.style.opacity=entry.opacity;}}}
   }catch(error){this.remove(entry);this.report('network.floating-presentation-failed',error.message,{objectId:entry.state.objectId});}
  }
  this.publish();
 }
 remove(entry){const index=this.entries.indexOf(entry);if(index>=0)this.entries.splice(index,1);entry.node?.remove();entry.shadow?.remove();}
 publish(){this.host.dataset.state=JSON.stringify({active:this.entries.map(e=>({objectId:e.state.objectId,remaining:e.state.remaining,position:e.position,opacity:e.opacity,ready:Boolean(e.node)})),events:this.events});}
}
