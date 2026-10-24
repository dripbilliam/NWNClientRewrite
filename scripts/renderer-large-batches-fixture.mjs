import * as T from 'three';import {RendererMainBatches} from '../src/renderer_main_batches.js';
const assert=(v,m)=>{if(!v)throw Error(m);};
function diff(a,b){let channels=0,max=0;for(let i=0;i<a.length;i++){const d=Math.abs(a[i]-b[i]);if(d){channels++;max=Math.max(max,d);}}return{channels,max};}
window.runLargeBatchesFixture=async()=>{
 const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(640,480,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
 const owner=new RendererMainBatches(renderer,{maxBatchMembers:128,maxTextureLayers:128,maxVertices:65536,minRepeatSize:16,maxBytes:64*1024*1024}),scene=new T.Scene(),camera=new T.PerspectiveCamera(50,4/3,.1,100),meshes=[],textures=[],rows=[];
 camera.position.set(0,18,20);camera.lookAt(0,0,0);scene.background=new T.Color('#17222d');scene.add(new T.AmbientLight(0xaaaaaa,.5));
 const light=new T.PointLight(0xffddcc,20,40);light.position.set(1,8,3);light.castShadow=true;light.shadow.mapSize.set(64,64);scene.add(light);
 for(let i=0;i<160;i++){const map=new T.DataTexture(Uint8Array.from({length:16*16*4},(_,j)=>j%4===3?255:(j*11+i*13)%256),16,16);map.colorSpace=T.SRGBColorSpace;map.needsUpdate=true;textures.push(map);const geometry=new T.BoxGeometry(.65,1,.65).toNonIndexed(),material=new T.MeshLambertMaterial({map,color:new T.Color(.5+i%3*.1,.6,.7)}),mesh=new T.Mesh(geometry,material);mesh.castShadow=mesh.receiveShadow=true;mesh.position.set(i%16-7.5,.5,Math.floor(i/16)-4.5);scene.add(mesh);meshes.push(mesh);}
 const read=()=>{const gl=renderer.getContext(),pixels=new Uint8Array(640*480*4),map=light.shadow.map,shadows=new Uint8Array(map.width*map.height*4);gl.readPixels(0,0,640,480,gl.RGBA,gl.UNSIGNED_BYTE,pixels);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,shadows);assert(gl.getError()===0,'WebGL error');return{pixels,shadows,calls:renderer.info.render.calls,triangles:renderer.info.render.triangles};};
 const draw=()=>owner.render(scene,camera);
 try{
  assert(owner.limit===128,'GPU cannot exercise the requested 128-member path');
  for(let frame=0;frame<9;frame++){
   await new Promise(requestAnimationFrame);
   if(frame===1)meshes[127].position.y=1.3;if(frame===2)meshes[128].material.color.setRGB(.8,.1,.3);if(frame===3)meshes[64].visible=false;if(frame===4)meshes[64].visible=true;if(frame===5)meshes[64].material.depthWrite=false;
   if(frame===6){const ext=renderer.getContext().getExtension('WEBGL_lose_context');assert(ext,'Context loss unavailable');await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Context restore deadline')),10000);renderer.domElement.addEventListener('webglcontextrestored',()=>{clearTimeout(timer);resolve();},{once:true});renderer.domElement.addEventListener('webglcontextlost',()=>setTimeout(()=>ext.restoreContext(),50),{once:true});ext.loseContext();});}
   if(frame===7)textures[100].offset.x=.2;if(frame===8)meshes[22].onBeforeRender=()=>{meshes[150].material.opacity=.9;};
   owner.enabled=false;draw();const before=read();owner.enabled=true;draw();draw();draw();const after=read(),pixels=diff(before.pixels,after.pixels),shadows=diff(before.shadows,after.shadows);rows.push({frame,pixels,shadows,trianglesEqual:before.triangles===after.triangles,callsBefore:before.calls,callsAfter:after.calls,batches:owner.snapshot()});
  }
  const screenshot=renderer.domElement.toDataURL('image/png'),buffers=owner.batches.flatMap(b=>b.buffers);owner.dispose();assert(buffers.every(b=>!renderer.getContext().isBuffer(b)),'Owned buffer survived');assert(owner.root.parent===null&&owner.palettes.bytes===0&&owner.vertexBytes===0,'Batch owner leaked');return{passed:rows.every(r=>r.pixels.channels===0&&r.shadows.channels===0&&r.trianglesEqual)&&rows.some(r=>r.batches.instances>=128&&r.callsAfter<r.callsBefore),rows,screenshot};
 }finally{owner.dispose();for(const m of meshes){m.geometry.dispose();m.material.dispose();}for(const t of textures)t.dispose();light.shadow.dispose();renderer.dispose();renderer.forceContextLoss();}
};
