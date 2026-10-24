import * as T from 'three';
import {RendererZeroLightWork} from '../src/renderer_zero_light_work.js';
import {installModelLightShaders} from '../src/model_light.js';
const assert=(value,message)=>{if(!value)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
const progress=(experimental,frame,stage)=>{window.fixtureProgress={experimental,frame,stage};console.info('NWN_ZERO_LIGHT_PROGRESS '+JSON.stringify(window.fixtureProgress));};

// Deferred correctness only. Compare unmodified Three programs in a separate
// renderer with guarded programs, including enabling/disabling during play.
// No shader timings from this fixture constitute whole-client FPS evidence.
window.runZeroLightWorkFixture=async({nativeLegacy=false}={})=>{
 const originalChunks={fragment:T.ShaderChunk.lights_fragment_begin,pars:T.ShaderChunk.lights_pars_begin};
 try{
 if(nativeLegacy)installModelLightShaders();
 const results=[];let screenshot;
 for(const experimental of [false,true]){
  progress(experimental,-1,'create');
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(512,384,false);renderer.setPixelRatio(1);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const fragmentsBefore=T.ShaderChunk.lights_fragment_begin,parsBefore=T.ShaderChunk.lights_pars_begin,owner=experimental?new RendererZeroLightWork(renderer,T.ShaderChunk):null;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(48,4/3,.1,120),ortho=new T.OrthographicCamera(-10,10,7.5,-7.5,.1,120),rows=[],geometries=new Set(),materials=new Set(),textures=new Set();
  scene.background=new T.Color('#182a30');scene.fog=new T.Fog('#182a30',30,70);scene.add(new T.AmbientLight(0xaabbcc,.3));
  const bitmap=new T.DataTexture(new Uint8Array([255,255,255,255,80,120,160,0,200,140,80,255,130,220,170,255]),2,2);bitmap.colorSpace=T.SRGBColorSpace;bitmap.needsUpdate=true;textures.add(bitmap);
  const floor=new T.Mesh(new T.PlaneGeometry(30,30),new T.MeshLambertMaterial({color:0x776655}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);geometries.add(floor.geometry);materials.add(floor.material);
  const meshes=[],root=new T.Group();scene.add(root);
  for(let i=0;i<24;i++){
   const Type=[T.MeshLambertMaterial,T.MeshPhongMaterial,T.MeshStandardMaterial][i%3],material=new Type({color:new T.Color().setHSL(i*.137%1,.45,.45),map:i%4===0?bitmap:null,alphaTest:i%4===0?.3:0}),geometry=i%2?new T.SphereGeometry(.5,7,5):new T.BoxGeometry(.8,1.2,.7),mesh=new T.Mesh(geometry,material);
   mesh.position.set(i%6*1.6-4, .8,Math.floor(i/6)*1.7-2.5);mesh.castShadow=mesh.receiveShadow=true;root.add(mesh);meshes.push(mesh);geometries.add(geometry);materials.add(material);
  }
  const lights=[];const addLight=i=>{
   const light=new T.PointLight(new T.Color().setHSL(i*.173%1,.4,.65),i<8?(nativeLegacy?1:8):0,i<8?3.5:0,nativeLegacy?-9/(2*3.5**2):2);light.position.set(i<8?i%4*3-4.5:0,i<8?2.5:0,i<8?Math.floor(i/4)*5-2.5:0);light.castShadow=i<2;light.shadow.mapSize.set(64,64);scene.add(light);lights.push(light);
  };for(let i=0;i<64;i++)addLight(i);
  const sun=new T.DirectionalLight(0xaaccff,.4);sun.position.set(8,12,4);scene.add(sun);
  const read=async()=>{
   const gl=renderer.getContext(),pixels=new Uint8Array(512*384*4);gl.readPixels(0,0,512,384,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const shadows=[];
   for(const light of lights.slice(0,2)){const map=light.shadow.map,bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);shadows.push(await hash(bytes));}
   assert(gl.getError()===gl.NO_ERROR,'WebGL error');return {pixels:await hash(pixels),shadows,draw:{...renderer.info.render}};
  };
  try{
   for(let frame=0;frame<32;frame++){
    progress(experimental,frame,'begin');await new Promise(resolve=>setTimeout(resolve,8));
    camera.position.set(12+Math.sin(frame*.2),11,17);camera.lookAt(0,0,0);ortho.position.copy(camera.position);ortho.lookAt(0,0,0);
    lights[1].position.x=-3+Math.sin(frame*.13)*2;lights[2].color.setHSL(frame*.031%1,.6,.5);meshes[3].position.y=.8+Math.sin(frame*.2)*.3;
    if(frame===3)root.visible=false;if(frame===4)root.visible=true;
    if(frame===5)lights[3].distance=0;if(frame===6)lights[3].distance=3.5;
    if(frame===7)lights[4].intensity=0;if(frame===9)lights[4].intensity=8;
    if(frame===10)lights[5].decay=0;if(frame===11)lights[5].decay=-2;if(frame===12)lights[5].decay=2;
    if(frame===12)meshes[4].scale.x=-1;
    if(frame===13){meshes[7].material.transparent=true;meshes[7].material.opacity=.45;meshes[7].material.needsUpdate=true;}
    if(frame===14)for(let i=64;i<128;i++)addLight(i);
    if(frame===16){
     progress(experimental,frame,'lose context');
     const extension=renderer.getContext().getExtension('WEBGL_lose_context');assert(extension,'Context loss unavailable');
     await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Context restore timeout')),10000);renderer.domElement.addEventListener('webglcontextrestored',()=>{clearTimeout(timer);resolve();},{once:true});renderer.domElement.addEventListener('webglcontextlost',()=>setTimeout(()=>extension.restoreContext(),50),{once:true});extension.loseContext();});
     progress(experimental,frame,'context restored');
    }
    if(frame===18)meshes[8].layers.set(2);if(frame===19)meshes[8].layers.set(0);
    if(frame===23){meshes[9].material.side=T.DoubleSide;meshes[9].material.needsUpdate=true;}
    if(frame===24)lights[6].distance=.0000000001;if(frame===25)lights[6].distance=3.5;
    if(frame===27)meshes[10].position.copy(lights[7].position);
    // Both controls remain useful: the guarded program's ordinary branch
    // must match unmodified Three before and after the first enabled frame.
    if(owner)owner.enabled=![0,1,20,21].includes(frame);
    progress(experimental,frame,'draw');renderer.shadowMap.needsUpdate=true;renderer.render(scene,frame===22?ortho:camera);progress(experimental,frame,'read');
    rows.push({frame,...await read(),lighting:owner?.snapshot()??null});
   }
   progress(experimental,32,'dispose');screenshot=renderer.domElement.toDataURL('image/png');const beforeDispose=owner?.snapshot()??null;owner?.dispose();
   assert(T.ShaderChunk.lights_fragment_begin===fragmentsBefore&&T.ShaderChunk.lights_pars_begin===parsBefore,'Shader chunks leaked');
   for(const program of renderer.info.programs){const uniform=program.getUniforms().map.nwnSkipZeroLightWork;if(uniform)assert(renderer.getContext().getUniform(program.program,uniform.addr)===0,'Compiled shader remained enabled after disposal');}
   renderer.render(scene,camera);const afterDispose=await read();
   results.push({experimental,rows,beforeDispose,afterDispose,programsRetired:owner?.programs.size??0});
  }finally{
   owner?.dispose();for(const light of lights)light.shadow.dispose();for(const material of materials)material.dispose();for(const geometry of geometries)geometry.dispose();for(const texture of textures)texture.dispose();renderer.dispose();renderer.forceContextLoss();
  }
 }
 const comparisons=results[0].rows.map((a,i)=>{const b=results[1].rows[i];return{frame:i,pixels:a.pixels===b.pixels,shadows:JSON.stringify(a.shadows)===JSON.stringify(b.shadows),calls:a.draw.calls===b.draw.calls,triangles:a.draw.triangles===b.draw.triangles,enabled:b.lighting.enabled,uploads:b.lighting.uploads};});
 const cleanupExact=results[0].afterDispose.pixels===results[1].afterDispose.pixels&&JSON.stringify(results[0].afterDispose.shadows)===JSON.stringify(results[1].afterDispose.shadows);
 return{passed:comparisons.every(c=>c.pixels&&c.shadows&&c.calls&&c.triangles)&&comparisons.some(c=>c.enabled&&c.uploads>0)&&cleanupExact&&results[1].programsRetired===0,scope:'32 authored GPU cases; not performance acceptance',nativeLegacy,comparisons,cleanupExact,results,screenshot};
 }finally{
  T.ShaderChunk.lights_fragment_begin=originalChunks.fragment;T.ShaderChunk.lights_pars_begin=originalChunks.pars;
 }
};
