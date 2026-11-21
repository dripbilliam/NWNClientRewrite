import {WebGLRenderTarget} from 'three';
import {captureFrozenGLCommands} from './frozen-gl-stream.mjs';
const difference=(a,b)=>{let channels=0,pixels=0,max=0;for(let i=0;i<a.length;i+=4){let changed=false;for(let c=0;c<4;c++){const d=Math.abs(a[i+c]-b[i+c]);if(d){channels++;changed=true;max=Math.max(max,d);}}if(changed)pixels++;}return{channels,pixels,max};};
export function auditReplayFrozenStream({renderer,scene,draw,passes=3,now=()=>performance.now()}){
 if(!Number.isInteger(passes)||passes<1||passes>5)throw Error('Frozen audit pass count');
 const gl=renderer.getContext(),old=renderer.getRenderTarget();if(old!==null||gl.getError()!==gl.NO_ERROR)throw Error('Frozen audit needs a clean default target');
 const width=renderer.domElement.width,height=renderer.domElement.height,target=new WebGLRenderTarget(width,height,{samples:0});target.texture.colorSpace=renderer.outputColorSpace;let stream;
 const read=()=>{const pixels=new Uint8Array(width*height*4),shadows=[];renderer.readRenderTargetPixels(target,0,0,width,height,pixels);scene.traverseVisible(o=>{const map=o.isLight&&o.castShadow&&o.shadow?.map;if(map?.isWebGLRenderTarget){const bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);shadows.push({map,bytes});}});return{pixels,shadows};};
 const compare=(a,b)=>({pixels:difference(a.pixels,b.pixels),shadows:a.shadows.map((s,i)=>({sameTarget:b.shadows[i]?.map===s.map,...difference(s.bytes,b.shadows[i]?.bytes??new Uint8Array(s.bytes.length))})),shadowCountEqual:a.shadows.length===b.shadows.length});
 try{
  renderer.setRenderTarget(target);for(let i=0;i<3;i++)draw();const before=read();
  stream=captureFrozenGLCommands(gl,draw);const reference=read(),stable=compare(before,reference);
  const report={scope:'Frozen in-memory GL stream lower bound only; excludes all simulation, fresh culling/material/transform/light preparation and reused-shadow work. Not a gameplay FPS or goal acceptance test. No command/asset payload is saved.',eligibleForGameplay:false,commands:stream.counts,payloadBytes:stream.bytes,unsupported:stream.unsupported,referenceStable:stable};
  if(stream.unsupported.length)return{...report,passed:false};
  stream.replay();const firstReplay=compare(reference,read());gl.finish();const start=now();for(let i=0;i<passes;i++)stream.replay();const submitted=now();gl.finish();const drained=now(),repeatReplay=compare(reference,read());
  const exact=c=>c.pixels.channels===0&&c.shadowCountEqual&&c.shadows.every(s=>s.sameTarget&&s.channels===0);if(gl.getError()!==gl.NO_ERROR)throw Error('Frozen stream WebGL error');
  return{...report,passed:exact(stable)&&exact(firstReplay)&&exact(repeatReplay),firstReplay,repeatReplay,passes,cpuSubmitMs:submitted-start,drainedMs:drained-start,drainedPerPassMs:(drained-start)/passes};
 }finally{stream?.clear();renderer.resetState();renderer.setRenderTarget(old);target.dispose();}
}
