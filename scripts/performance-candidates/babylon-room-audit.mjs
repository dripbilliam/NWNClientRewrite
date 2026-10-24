import * as T from 'three';
import {BabylonRoomAdapter} from './babylon-room-adapter.mjs';

const stats=values=>{const sorted=values.slice().sort((a,b)=>a-b);return{frames:values.length,averageMs:values.reduce((a,b)=>a+b,0)/values.length,p95Ms:sorted[Math.ceil(sorted.length*.95)-1],maxMs:sorted.at(-1)};};
const image=(bytes,width,height,flip)=>{const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;const context=canvas.getContext('2d'),data=context.createImageData(width,height);for(let y=0;y<height;y++)data.data.set(bytes.subarray((flip?height-y-1:y)*width*4,(flip?height-y:y+1)*width*4),y*width*4);context.putImageData(data,0,0);return canvas.toDataURL('image/png');};
export function compareRoomPixels(reference,actual,width,height){
 if(reference.length!==width*height*4||actual.length!==reference.length)throw Error('Framebuffer dimensions differ');
 let pixels=0,channels=0,max=0;const histogram=new Uint32Array(256),channelDifferences=[0,0,0,0],samples=[];
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){let changed=false;for(let c=0;c<4;c++){const delta=Math.abs(reference[((height-y-1)*width+x)*4+c]-actual[(y*width+x)*4+c]);if(delta){changed=true;channels++;channelDifferences[c]++;max=Math.max(max,delta);histogram[delta]++;}}if(changed){pixels++;if(samples.length<12)samples.push({x,y,reference:Array.from(reference.subarray(((height-y-1)*width+x)*4,((height-y-1)*width+x)*4+4)),actual:Array.from(actual.subarray((y*width+x)*4,(y*width+x)*4+4))});}}
 return{pixels,channels,max,exact:pixels===0,channelDifferences,samples,histogram:Array.from(histogram.entries()).filter(([,count])=>count)};
}
export function capturePreparedRoomLights({renderer,scene,camera,draw}){
 const api=renderer.nwnDrawAPI;if(!api||typeof draw!=='function')throw Error('Babylon room audit requires the owned prepared-light bridge');
 const previous=api.afterPass;let lights;
 api.afterPass=(s,c)=>{previous?.(s,c);if(s===scene&&c===camera){const state=api.getState()?.lights?.state;if(state)lights={point:state.point.map(p=>({position:p.position.clone(),color:p.color.clone(),decay:p.decay,distance:p.distance})),ambient:state.ambient.slice()};}};
 try{draw();}finally{api.afterPass=previous;}
 if(!lights)throw Error('No owned prepared light pass captured');
 return lights;
}
export async function auditBabylonRoom({renderer,scene,camera,draw,selectMode=()=>{},lit=true,particles=true,frames=60,warmup=20,profile=false}){
 const started=performance.now(),width=renderer.domElement.width,height=renderer.domElement.height,canvas=document.createElement('canvas');canvas.width=width;canvas.height=height;
 const lights=capturePreparedRoomLights({renderer,scene,camera,draw});
 const source=renderer.renderLists.get(scene,0);
 const items=[...source.opaque,...source.transmissive,...source.transparent],copies=[],referenceScene=new T.Scene();referenceScene.background=new T.Color(0);
 let adapter,referenceTarget;const originalMode='cooperative-draws';
 try{
  adapter=await BabylonRoomAdapter.create({canvas,items,lightState:lights,lit,particles});adapter.update(camera);if(!adapter.rows.length)throw Error('No Babylon room draws admitted');
  for(const row of adapter.rows){
   const m=row.item.material,texture=row.texture.pixels,map=new T.DataTexture(texture.data.slice(),texture.width,texture.height,T.RGBAFormat,T.UnsignedByteType);
   map.colorSpace=row.map?.colorSpace??T.NoColorSpace;map.flipY=!!row.map?.flipY;map.generateMipmaps=false;map.magFilter=map.minFilter=T.LinearFilter;map.wrapS=row.map?.wrapS??T.ClampToEdgeWrapping;map.wrapT=row.map?.wrapT??T.ClampToEdgeWrapping;map.channel=row.map?.channel??0;if(row.map){map.matrixAutoUpdate=false;map.matrix.copy(row.map.matrix);}map.needsUpdate=true;copies.push(map);
   let material;if(row.particle){material=m.clone();material.uniforms.particleMap.value=map;}
   else if(lit&&m.isMeshLambertMaterial)material=m.clone();else material=new T.MeshBasicMaterial({color:m.color,opacity:m.opacity,transparent:m.transparent,alphaTest:m.alphaTest,side:m.side,depthTest:m.depthTest,depthWrite:m.depthWrite,blending:m.blending});
   if(!row.particle)material.map=map;material.fog=false;material.toneMapped=false;copies.push(material);
   const geometry=row.item.geometry.clone();geometry.setDrawRange(row.range.begin,row.range.count);geometry.clearGroups();copies.push(geometry);
   const proxy=new T.Mesh(geometry,material);proxy.matrixAutoUpdate=false;proxy.matrixWorldAutoUpdate=false;proxy.matrixWorld.copy(row.item.object.matrixWorld);proxy.frustumCulled=false;proxy.renderOrder=referenceScene.children.length;referenceScene.add(proxy);
  }
  scene.traverseVisible(light=>{if((light.isPointLight||light.isAmbientLight)&&light.layers.test(camera.layers)){const copy=light.clone();copy.children.length=0;copy.castShadow=false;copy.position.setFromMatrixPosition(light.matrixWorld);copy.matrixAutoUpdate=true;copy.matrixWorldAutoUpdate=true;copy.updateMatrix();copy.updateMatrixWorld(true);referenceScene.add(copy);}});
  await adapter.ready();referenceTarget=new T.WebGLRenderTarget(width,height,{samples:0});referenceTarget.texture.colorSpace=T.LinearSRGBColorSpace;
  const drawReference=()=>{const old=renderer.getRenderTarget(),tone=renderer.toneMapping;try{renderer.toneMapping=T.NoToneMapping;renderer.setRenderTarget(referenceTarget);renderer.render(referenceScene,camera);}finally{renderer.setRenderTarget(old);renderer.toneMapping=tone;}};
  selectMode('baseline');drawReference();const reference=new Uint8Array(width*height*4);renderer.readRenderTargetPixels(referenceTarget,0,0,width,height,reference);
  if(renderer.info.render.calls!==adapter.rows.length)throw Error('Three reference draw coverage mismatch');
  adapter.render();if(adapter.engine._drawCalls.current!==adapter.rows.length)throw Error('Babylon draw coverage mismatch: '+adapter.engine._drawCalls.current+'/'+adapter.rows.length);const actual=new Uint8Array(await adapter.engine.readPixels(0,0,width,height,true,true));
  const pixelComparison=compareRoomPixels(reference,actual,width,height),preparedMs=performance.now()-started;
  // These deliberately report CPU preparation/submission, never gameplay FPS.
  // A fence follows every sample, outside the CPU timer; no queue buildup.
  const gl=renderer.getContext(),fence=()=>new Promise((resolve,reject)=>{const sync=gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE,0);gl.flush();const until=performance.now()+10000,check=()=>{const status=gl.clientWaitSync(sync,0,0);if(status===gl.ALREADY_SIGNALED||status===gl.CONDITION_SATISFIED){gl.deleteSync(sync);resolve();}else if(status===gl.WAIT_FAILED||performance.now()>until){gl.deleteSync(sync);reject(Error('Babylon reference fence failed'));}else setTimeout(check,0);};check();});
  const measurements=[];adapter.profileStages=profile;let profileIndex=0;
  for(const mode of ['three-stock','babylon-webgpu','babylon-webgpu','three-stock']){
   selectMode('baseline');const cpu=[],completion=[],updates=[],sceneTimes=[],submissions=[];let recording=false;
   try{for(let frame=0;frame<frames+warmup;frame++){if(profile&&mode==='babylon-webgpu'&&frame===warmup){await window.sceneReplayProfiler.start('babylon-steady-'+profileIndex++);recording=true;}const start=performance.now();let updated=start;if(mode==='babylon-webgpu'){adapter.update(camera,lights);updated=performance.now();adapter.render();}else drawReference();const submitted=performance.now();if(mode==='babylon-webgpu')await adapter.engine._device.queue.onSubmittedWorkDone();else await fence();if(frame>=warmup){cpu.push(submitted-start);completion.push(performance.now()-start);if(profile&&mode==='babylon-webgpu'){updates.push(updated-start);sceneTimes.push(adapter.lastStages.sceneRenderMs);submissions.push(adapter.lastStages.endFrameMs);}}}}finally{if(recording)await window.sceneReplayProfiler.stop();}
   measurements.push({mode,cpuPreparationAndSubmission:stats(cpu),completionWallIncludingFence:stats(completion),...(updates.length?{stageTimings:{adapterUpdate:stats(updates),babylonSceneRender:stats(sceneTimes),endFrameSubmission:stats(submissions)},profiled:true}:{})});
  }
  return{executionSucceeded:adapter.errors.length===0,passed:pixelComparison.exact&&adapter.errors.length===0,fullGameParity:false,...adapter.snapshot(),buffer:[width,height],preparedMs,pixelComparison,measurements,screenshot:image(actual,width,height,false),referenceScreenshot:image(reference,width,height,true),sourceDraws:items.length,scope:'Equivalent captured-room base-mip opaque/transparent NWN Lambert/basic/particle subset, point+ambient lighting. No shadows, fog or full-game FPS claim. Strict pixel comparison; no tolerance.'};
 }finally{selectMode(originalMode);adapter?.dispose();referenceTarget?.dispose();for(const copy of copies)copy.dispose();}
}
