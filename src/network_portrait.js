import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {portraitImage} from './portrait_image.js';
import {portraitCandidates} from './portrait_resource.js';

const caches=new WeakMap();
// This view requests tiny1; party requests small2 or medium3.
export async function networkPortrait(assets,tables,row,size,{crop=false}={}){
 if(!assets)return null;
 const custom=row.portrait>0xfffd,base=custom?row.portraitRef:tables?.portraits?.rows.get(row.portrait)?.BaseResRef;
 if(!base||base==='****')return null;
 const name=custom?base:'po_'+base,key=name+':'+size+':'+crop;
 let cache=caches.get(assets);if(!cache)caches.set(assets,cache=new Map());
 if(!cache.has(key))cache.set(key,(async()=>{
  let failure;for(const candidate of portraitCandidates(name,size)){
   try{const image=await(assets.image?assets.image(candidate):portraitImage(assets.resolver,candidate)),canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=crop?Math.min(image.height,Math.round(image.width*100/64)):image.height;canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);return canvas.toDataURL();}catch(error){failure=error;}
  }
  runtimeDiagnostics.record('network.portrait-unavailable','Native portrait is unavailable',{objectId:row.id,resource:name,size,reason:failure?.message});return null;
 })());
 return cache.get(key);
}
