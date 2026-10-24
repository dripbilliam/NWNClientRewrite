function difference(before,after){
 if(before.length!==after.length)throw Error('Framebuffer dimensions changed');
 let channels=0,pixels=0,max=0,lastPixel=-1;
 for(let i=0;i<before.length;i++){const delta=Math.abs(before[i]-after[i]);if(delta){channels++;max=Math.max(max,delta);const pixel=i>>2;if(pixel!==lastPixel){pixels++;lastPixel=pixel;}}}
 return{channels,pixels,max};
}

// Diagnostic only, outside measured frames. All rendering/reads execute in one
// synchronous task, so RAF animation, particle simulation and network delivery
// cannot advance between the reference and candidate images. A repeated
// reference detects callbacks that still change draw-time state.
export function compareReplayFrame({renderer,scene,draw,setMode,getMode,modes=['flat-scene','broad-main','broad-flat'],target=null,getExecution=null}){
 const gl=renderer.getContext(),canvas=renderer.domElement,width=canvas.width,height=canvas.height,original=getMode(),rows=[];
 if(renderer.getRenderTarget()!==null||gl.getError()!==gl.NO_ERROR)throw Error('Parity requires a clean default framebuffer');
 if(target&&(target.width!==width||target.height!==height||!target.isWebGLRenderTarget||target.samples!==0))throw Error('Parity target must match the canvas and have no MSAA');
 const read=()=>{
  const pixels=new Uint8Array(width*height*4),shadows=[];if(target)renderer.readRenderTargetPixels(target,0,0,width,height,pixels);else gl.readPixels(0,0,width,height,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
  scene.traverseVisible(light=>{const map=light.shadow?.map;if(!light.isLight||!light.castShadow||!map?.isWebGLRenderTarget)return;const bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);shadows.push({id:light.id,width:map.width,height:map.height,bytes});});
  if(gl.getError()!==gl.NO_ERROR)throw Error('Parity framebuffer read failed');return{pixels,shadows};
 };
 const render=mode=>{setMode(mode);const samples=[];for(let i=0;i<3;i++){draw();if(getExecution)samples.push(getExecution());}return{...read(),execution:samples};};
 const compare=(a,b)=>{
  if(a.shadows.length!==b.shadows.length)throw Error('Shadow map membership changed');
  const shadows=a.shadows.map((map,i)=>{const other=b.shadows[i];if(map.id!==other.id||map.width!==other.width||map.height!==other.height)throw Error('Shadow map identity changed');return{id:map.id,...difference(map.bytes,other.bytes)};});
  const pixels=difference(a.pixels,b.pixels);return{pixels,shadows,execution:b.execution,exact:pixels.channels===0&&shadows.every(s=>s.channels===0)};
 };
 let referenceStable;
 try{
  if(target)renderer.setRenderTarget(target);
  const before=render('baseline');for(const mode of modes){if(!['flat-scene','broad-main','broad-flat','particle-frame','lean-submit','particle-lean','light-records','particle-lights','lean-all','wide-batches','wide-all','point-grid','grid-all','command-batches','command-all','merged-batches','merged-all','merged-samples','shared-frame','warm-draws','planned-draws','prefix-draws','cooperative-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main','spatial-draws','opaque-alpha','keyhole-inactive','native-discard'].includes(mode))throw Error('Unknown parity candidate');rows.push({mode,...compare(before,render(mode))});}
  referenceStable=compare(before,render('baseline'));
 }finally{try{setMode(original);}finally{if(target)renderer.setRenderTarget(null);}}
 return{scope:target?'Same-task independent non-MSAA color target and active shadow maps; separate from default framebuffer/UI/native/FPS checks':'Same-task world canvas and active shadow maps; no UI/native fidelity or FPS claim',target:target?'independent-no-msaa':'default-framebuffer',width,height,referenceStable,comparisons:rows,modeRestored:getMode()===original,passed:referenceStable.exact&&rows.every(row=>row.exact)&&getMode()===original};
}
