import * as T from 'three';
import {RendererCommandBatches} from '../src/renderer_command_batches.js';
import {installModelLightShaders} from '../src/model_light.js';
const assert=(v,m)=>{if(!v)throw Error(m);};
const diff=(a,b)=>{let channels=0,max=0;for(let i=0;i<a.length;i++){const d=Math.abs(a[i]-b[i]);if(d){channels++;max=Math.max(max,d);}}return{channels,max};};
async function runCommandCase(merged,sampleAll=false,arrayPalette=false){
 installModelLightShaders();
 const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(640,480,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
 const owner=new RendererCommandBatches(renderer,{merged,sampleAll,arrayPalette,samplerReserve:merged?()=>1:null,maxRows:512,maxVertices:16384}),scene=new T.Scene(),camera=new T.PerspectiveCamera(50,4/3,.1,100),meshes=[],textures=[],rows=[],gl=renderer.getContext(),invalidDeletes=[];
 for(const kind of ['Buffer','Texture','Framebuffer','Renderbuffer','Program','VertexArray']){const before=gl['delete'+kind];gl['delete'+kind]=function(value){if(value&&!gl.isContextLost()&&!gl['is'+kind](value)&&invalidDeletes.length<12)invalidDeletes.push({kind,stack:new Error().stack});return before.call(this,value);};}
 camera.position.set(12,18,20);camera.lookAt(0,0,0);scene.background=new T.Color('#17222d');scene.fog=new T.Fog('#17222d',18,80);scene.add(new T.AmbientLight(0xaabbcc,.5));
 const light=new T.PointLight(0xffddcc,20,40,-2);light.position.set(1,8,3);light.castShadow=true;light.shadow.mapSize.set(64,64);scene.add(light);
 for(let i=0;i<8;i++){const bytes=Uint8Array.from({length:16*16*4},(_,j)=>j%4===3?(j%16===3?0:255):(j*11+i*13)%256),map=new T.DataTexture(bytes,16,16);map.colorSpace=T.SRGBColorSpace;map.wrapS=map.wrapT=T.RepeatWrapping;map.minFilter=map.magFilter=T.LinearFilter;map.needsUpdate=true;textures.push(map);}
 assert(gl.getExtension('WEBGL_compressed_texture_s3tc'),'S3TC unavailable');gl.getExtension('WEBGL_compressed_texture_s3tc_srgb');
 for(let i=0;i<8;i++){const format=i%2?T.RGBA_S3TC_DXT5_Format:T.RGBA_S3TC_DXT1_Format,stride=i%2?16:8,mips=[];for(let level=0;level<5;level++){const size=Math.max(1,16>>level),data=new Uint8Array(Math.ceil(size/4)**2*stride);for(let at=0;at<data.length;at+=stride){let color=at;if(stride===16){data[at]=220;data[at+1]=30;data.fill(0x24,at+2,at+8);color+=8;}const high=0xe800+i*32,low=0x021f+i*32;data[color]=high&255;data[color+1]=high>>8;data[color+2]=low&255;data[color+3]=low>>8;data.fill(0xe4,color+4,color+8);}mips.push({width:size,height:size,data});}const map=new T.CompressedTexture(mips,16,16,format,T.UnsignedByteType);map.colorSpace=i<4?T.SRGBColorSpace:T.NoColorSpace;map.wrapS=map.wrapT=T.RepeatWrapping;map.minFilter=T.LinearMipmapLinearFilter;map.magFilter=T.LinearFilter;map.generateMipmaps=false;map.needsUpdate=true;textures.push(map);}
 const geometry=new T.BoxGeometry(.65,1,.65).toNonIndexed();
 for(let i=0;i<160;i++){const material=new T.MeshLambertMaterial({map:textures[i%textures.length],color:new T.Color(.5+i%3*.1,.6,.7)}),mesh=new T.Mesh(geometry,material);mesh.castShadow=mesh.receiveShadow=true;mesh.position.set(i%16-7.5,.5,Math.floor(i/16)-4.5);scene.add(mesh);meshes.push(mesh);}
 const read=()=>{const pixels=new Uint8Array(640*480*4),map=light.shadow.map,shadows=new Uint8Array(map.width*map.height*4);gl.readPixels(0,0,640,480,gl.RGBA,gl.UNSIGNED_BYTE,pixels);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,shadows);assert(gl.getError()===0,'WebGL error');return{pixels,shadows,calls:renderer.info.render.calls,triangles:renderer.info.render.triangles};};
 const draw=()=>owner.render(scene,camera);
 try{
  for(let frame=0;frame<15;frame++){
   await new Promise(requestAnimationFrame);
   if(frame===1)meshes[127].position.y=1.3;
   if(frame===2){meshes[128].material.color.setRGB(.8,.1,.3);meshes[20].material.emissive.setRGB(.1,.3,.05);}
   if(frame===3)meshes[64].visible=false;
   if(frame===4){meshes[64].visible=true;meshes[64].material.depthWrite=false;}
   if(frame===5){textures[3].offset.set(.21,.13);textures[3].rotation=.3;textures[3].repeat.set(.8,1.2);meshes[8].scale.set(1.4,.6,1.1);}
   if(frame===6){meshes[30].material.transparent=true;meshes[30].material.opacity=.5;meshes[31].scale.x=-1;}
   if(frame===7){meshes[41].material.alphaTest=.3;meshes[42].material.polygonOffset=true;meshes[42].material.polygonOffsetFactor=1;}
   if(frame===8){const ext=gl.getExtension('WEBGL_lose_context');assert(ext,'Context loss unavailable');await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Context restore deadline')),10000);renderer.domElement.addEventListener('webglcontextrestored',()=>{clearTimeout(timer);resolve();},{once:true});renderer.domElement.addEventListener('webglcontextlost',()=>{geometry.dispose();for(const m of meshes)m.material.dispose();for(const t of textures)t.dispose();light.shadow.dispose();setTimeout(()=>ext.restoreContext(),50);},{once:true});ext.loseContext();});}
   if(frame===9){geometry.attributes.normal.array[0]=.1;geometry.attributes.normal.needsUpdate=true;}
   if(frame===10){camera.position.x+=2;camera.lookAt(0,0,0);}
   if(frame===11)meshes[22].onBeforeRender=()=>{meshes[150].material.opacity=.9;};
   if(frame===12)meshes[22].onBeforeRender=T.Object3D.prototype.onBeforeRender;
   if(frame===13){const map=new T.DataTexture(new Uint8Array([10,240,80,255]),1,1);textures.push(map);meshes[0].material.map=map;}if(frame===14)meshes[0].material.map.needsUpdate=true;
   owner.enabled=false;draw();const before=read();owner.enabled=true;draw();draw();draw();const after=read();rows.push({frame,pixels:diff(before.pixels,after.pixels),shadows:diff(before.shadows,after.shadows),trianglesEqual:before.triangles===after.triangles,callsBefore:before.calls,callsAfter:after.calls,batches:owner.snapshot()});
  }
  const screenshot=renderer.domElement.toDataURL('image/png');owner.dispose();assert(owner.snapshot().bytes===0&&owner.root===null,'Command owner survived disposal');renderer.render(scene,camera);read();const debug=gl.getExtension('WEBGL_debug_renderer_info'),gpu=debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);return{passed:rows.every(r=>r.pixels.channels===0&&r.shadows.channels===0&&r.trianglesEqual)&&rows.some(r=>r.batches.instances>=128&&r.callsAfter<r.callsBefore)&&rows[11].batches.fallback==='render-callback'&&!invalidDeletes.length,rows,invalidDeletes,gpu,screenshot};
 }finally{owner.dispose();geometry.dispose();for(const m of meshes)m.material.dispose();for(const t of textures)t.dispose();light.shadow.dispose();renderer.dispose();renderer.forceContextLoss();}
}
window.runCommandBatchesFixture=async()=>{const results=[];for(const merged of [false,true])for(const sampleAll of [false,true])results.push(await runCommandCase(merged,sampleAll));for(const merged of [false,true])results.push(await runCommandCase(merged,false,true));const screenshot=results.at(-1).screenshot;for(const r of results)delete r.screenshot;return{passed:results.every(r=>r.passed),results,screenshot};};
