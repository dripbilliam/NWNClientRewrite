import {WebGLRenderTarget,NearestFilter,UnsignedByteType,RGBAFormat} from 'three';

const equal=(a,b)=>a?.length===b.length&&a.every((v,i)=>v===b[i]);
// Experimental point-shadow prefix cache. Only the leading stable casters are
// cached, preserving their original position before every live suffix draw.
// Both color AND depth are restored; no static/dynamic reorder or stale actors.
// Cached content never leaves GPU memory and is discarded on context loss.
export class RendererShadowPrefix {
 constructor(renderer,{stableFrames=30,minPrefix=16,maxBytes=128*1024*1024}={}){Object.assign(this,{renderer,stableFrames,minPrefix,maxBytes});this.enabled=false;this.states=new Map();this.stability=new WeakMap();this.bytes=0;this.stats={};this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);}
 begin(){this.stats={restored:0,rebuilt:0,prefixObjects:0,suffixObjects:0,fallback:0};}
 prefix(objects,cache,sourcesFor=null){let count=0,blocked=false;const inputs=[];for(const object of objects){const sources=sourcesFor?.(object);let stamp;if(sources){stamp=[object.geometry,object.material,object.customDistanceMaterial,sources.length];for(const source of sources){const value=cache.stamp(source);if(value===null){stamp=null;break;}stamp.push(source,value);}}else stamp=cache.stamp(object);let state=this.stability.get(object);const same=Array.isArray(stamp)?Array.isArray(state?.stamp)&&equal(state.stamp,stamp):state?.stamp===stamp;const stable=stamp!==null&&same?state.stable+Number(state.frame!==cache.frame):1;this.stability.set(object,{stamp,stable,frame:cache.frame});if(stamp===null||stable<this.stableFrames)blocked=true;if(!blocked){inputs.push(object,...(Array.isArray(stamp)?stamp:[stamp]));count++;}}return{count,inputs};}
 target(map){if(!map?.isWebGLRenderTarget||map.samples||map.depthBuffer!==true||map.stencilBuffer||map.texture.type!==UnsignedByteType||map.texture.format!==RGBAFormat)return null;const bytes=map.width*map.height*8;if(this.bytes+bytes>this.maxBytes)return null;const target=new WebGLRenderTarget(map.width,map.height,{minFilter:NearestFilter,magFilter:NearestFilter,depthBuffer:true,stencilBuffer:false,samples:0});target.texture.generateMipmaps=false;const r=this.renderer,previous=r.getRenderTarget(),face=r.getActiveCubeFace(),level=r.getActiveMipmapLevel();try{r.setRenderTarget(target);}finally{r.setRenderTarget(previous,face,level);}this.bytes+=bytes;return{target,bytes};}
 blit(source,destination){const r=this.renderer,gl=r.getContext(),src=r.properties.get(source).__webglFramebuffer,dst=r.properties.get(destination).__webglFramebuffer;if(!src||!dst||Array.isArray(src)||Array.isArray(dst)||source.width!==destination.width||source.height!==destination.height)throw Error('Unsupported prefix framebuffer');const read=gl.getParameter(gl.READ_FRAMEBUFFER_BINDING),write=gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING),scissor=gl.isEnabled(gl.SCISSOR_TEST);try{if(scissor)gl.disable(gl.SCISSOR_TEST);gl.bindFramebuffer(gl.READ_FRAMEBUFFER,src);gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER,dst);if(gl.checkFramebufferStatus(gl.READ_FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE||gl.checkFramebufferStatus(gl.DRAW_FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)throw Error('Incomplete prefix framebuffer');gl.blitFramebuffer(0,0,source.width,source.height,0,0,destination.width,destination.height,gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT,gl.NEAREST);if(gl.getError()!==gl.NO_ERROR)throw Error('Prefix depth/color blit failed');}finally{gl.bindFramebuffer(gl.READ_FRAMEBUFFER,read);gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER,write);if(scissor)gl.enable(gl.SCISSOR_TEST);}}
 render(light,objects,type,cache,draw,sourcesFor=null){
  if(!this.enabled||!light.isPointLight||this.renderer.clippingPlanes.length)return false;
  const {count,inputs}=this.prefix(objects,cache,sourcesFor);if(count<this.minPrefix||count===objects.length)return false;
  const map=light.shadow.map;if(!map)return false;let state=this.states.get(light);
  if(state&&(state.map!==map||state.target.width!==map.width||state.target.height!==map.height)){this.bytes-=state.bytes;state.target.dispose();this.states.delete(light);state=null;}
  if(!state){const owned=this.target(map);if(!owned)return false;state={...owned,map,key:null,inputs:null};this.states.set(light,state);}
  try{
   const key=cache.lightKey(light,type);
   if(!equal(state.key,key)||!equal(state.inputs,inputs)){draw(objects.slice(0,count));this.blit(map,state.target);state.key=cache.lightKey(light,type);state.inputs=inputs;this.stats.rebuilt++;}
   const gl=this.renderer.getContext(),before=gl.clear,framebuffer=this.renderer.properties.get(map).__webglFramebuffer,owner=this;let restored=false;
   function clear(mask){if(!restored&&(mask&gl.COLOR_BUFFER_BIT)&&(mask&gl.DEPTH_BUFFER_BIT)&&gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING)===framebuffer){owner.blit(state.target,map);restored=true;const remaining=mask&~(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);if(remaining)return before.call(this,remaining);return;}return before.call(this,mask);}
   gl.clear=clear;try{draw(objects.slice(count));}finally{if(gl.clear===clear)gl.clear=before;}
   if(!restored)throw Error('Native shadow clear was not intercepted');
   this.stats.restored++;this.stats.prefixObjects+=count;this.stats.suffixObjects+=objects.length-count;return true;
  }catch(error){state.key=null;state.inputs=null;this.stats.fallback++;this.stats.failure=error.message;return false;}
 }
 snapshot(){return{...this.stats,enabled:this.enabled,bytes:this.bytes,maps:this.states.size};}
 reset(){for(const state of this.states.values())state.target.dispose();this.states.clear();this.stability=new WeakMap();this.bytes=0;this.stats={};}
 dispose(){this.reset();this.enabled=false;this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
