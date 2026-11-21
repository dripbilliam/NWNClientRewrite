import * as T from 'three';
import {RendererPointLightPackets} from '../src/renderer_point_light_packets.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {CameraKeyholePresentation} from '../src/camera_keyhole_shader.js';
import {TargetPreviewShader} from '../src/target_preview_shader.js';
const assert=(v,m)=>{if(!v)throw Error(m);};
const hash=async b=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',b))].map(n=>n.toString(16).padStart(2,'0')).join('');
window.runPointLightPacketsFixture=async({targetShader,keyholeShader,compact=true}={})=>{
 const results=[];let screenshot;
 for(const enabled of [false,true]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(768,512,false);renderer.setPixelRatio(1);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  renderer.debug.onShaderError=(gl,program,vertex,fragment)=>{window.pointShaderFailure={vertex:gl.getShaderInfoLog(vertex),fragment:gl.getShaderInfoLog(fragment),program:gl.getProgramInfoLog(program)};};
  const owner=new RendererPointLightPackets(renderer,{enabled,compact}),shadows=new RendererShadowTraversal(renderer,{instances:true}),scene=new T.Scene(),camera=new T.PerspectiveCamera(46,1.5,.1,120),ortho=new T.OrthographicCamera(-14,14,9,-9,.1,120),target=new TargetPreviewShader();target.shader=targetShader;const keyhole=new CameraKeyholePresentation({renderer,camera});keyhole.shader=keyholeShader;scene.userData.nativeStaticTile=true;
  const geometry=new T.BoxGeometry(.8,1.4,.8),floor=new T.Mesh(new T.PlaneGeometry(40,40),new T.MeshLambertMaterial({color:0x889988}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor,new T.AmbientLight(0xaabbcc,.3));
  const texture=new T.DataTexture(new Uint8Array([255,180,150,255,80,120,180,255,120,240,170,255,240,180,60,255]),2,2);texture.colorSpace=T.SRGBColorSpace;texture.wrapS=texture.wrapT=T.RepeatWrapping;texture.needsUpdate=true;
  const meshDraws=[],meshes=[],materials=new Set([floor.material]),lights=[],rows=[];
  for(let i=0;i<96;i++){
   const material=new T.MeshLambertMaterial({color:new T.Color().setHSL(Math.floor(i/12)*.137%1,.4,.45),map:Math.floor(i/12)%2===0?texture:null,flatShading:true,side:T.DoubleSide});materials.add(material);
   const mesh=new T.Mesh(geometry,material);mesh.position.set(i%12*1.6-9, .8+Math.floor(i/12)*.02,Math.floor(i/12)*1.6-5.5);mesh.castShadow=true;mesh.receiveShadow=true;mesh.userData.nativeModelMesh=true;scene.add(mesh);meshes.push(mesh);
  }
  for(let i=0;i<64;i++){const light=new T.PointLight(new T.Color().setHSL(i*.173%1,.35,.7),4,6,2);light.position.set(i%8*2.4-8.5,4+i%3,Math.floor(i/8)*2-7);light.castShadow=i<15;light.shadow.mapSize.set(64,64);scene.add(light);lights.push(light);}
  const sun=new T.DirectionalLight(0xffeecc,.4);sun.position.set(10,20,12);sun.shadow.mapSize.set(64,64);Object.assign(sun.shadow.camera,{left:-15,right:15,top:15,bottom:-15,far:80});
  const hemi=new T.HemisphereLight(0x7799cc,0x554422,.2),spot=new T.SpotLight(0xccaaff,3,25);spot.position.set(0,9,0);scene.add(sun,hemi,spot);
  keyhole.bind(scene);target.bind(scene);const sourceHooks=meshes.map(m=>m.onBeforeRender);
  const particleMaterial=new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{particleMap:{value:texture}},vertexShader:'varying vec2 pUv;void main(){pUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',fragmentShader:'uniform sampler2D particleMap;varying vec2 pUv;void main(){gl_FragColor=vec4(texture2D(particleMap,pUv).rgb,.3);}'}),particle=new T.Mesh(geometry,particleMaterial);particle.position.set(0,3,0);materials.add(particleMaterial);scene.add(particle);
  let activeFrame=-1;const direct=renderer.renderBufferDirect;
  renderer.renderBufferDirect=function(camera,scene,geometry,material,object,group){const result=direct.call(this,camera,scene,geometry,material,object,group);if([26,27].includes(activeFrame)&&material.isMeshLambertMaterial&&meshes.includes(object)){const gl=renderer.getContext(),program=renderer.properties.get(material).currentProgram,u=program.getUniforms().map,fields={};for(const name of ['diffuse','opacity','emissive','nwnKeyhole_keyholeCanDissolve','nwnTarget_targetShape','receiveShadow'])if(u[name]?.addr)fields[name]=gl.getUniform(program.program,u[name].addr);meshDraws.push({frame:activeFrame,object:meshes.indexOf(object),fields});}return result;};
  try{
   for(let frame=0;frame<32;frame++){activeFrame=frame;
    window.fixtureProgress={enabled,frame,stage:'frame'};
    // A hidden offscreen window need not receive rAF. This is a correctness
    // fixture, not an FPS benchmark; a task yield keeps both variants moving.
    await new Promise(resolve=>setTimeout(resolve,8));
    camera.position.set(19+Math.sin(frame*.2)*3,19,24);camera.lookAt(0,0,0);ortho.position.copy(camera.position);ortho.lookAt(0,0,0);
    lights[2].color.setHSL(frame*.031%1,.65,.55);lights[1].intensity=3+Math.sin(frame*.17);lights[3].position.x=-2+Math.sin(frame*.2);meshes[4].position.y=.8+Math.sin(frame*.2)*.3;
    if(frame===5)lights[63].visible=false;if(frame===6)lights[63].visible=true;
    if(frame===7){meshes[1].material.transparent=true;meshes[1].material.opacity=.6;meshes[1].material.needsUpdate=true;}
    if(frame===8)meshes[5].scale.set(-1,1.3,.8);
    target.uniforms.targetShape.value=frame>=9?1:0;target.uniforms.targetShapeSizeX.value=5;target.uniforms.targetShapeColour.value.set(.1,.2,.5,.3);target.uniforms.playerPosition.value.set(0,0,0);
    if(frame===10)meshes[2].onBeforeRender=function(){const u=renderer.properties.get(meshes[0].material).uniforms;if(u?.pointLights.value[0])u.pointLights.value[0].color.r=.123;};
    if(frame===11)meshes[2].onBeforeRender=sourceHooks[2];
    if(frame===12){texture.onUpdate=()=>{};texture.needsUpdate=true;}if(frame===13){texture.onUpdate=null;meshes[2].material.map=texture;meshes[2].material.needsUpdate=true;}
    if(frame===14)scene.overrideMaterial=new T.MeshLambertMaterial({color:0xccaaff});
    if(frame===15){scene.overrideMaterial.dispose();scene.overrideMaterial=null;}
    if(frame===16){
     window.fixtureProgress={enabled,frame,stage:'context'};const extension=renderer.getContext().getExtension('WEBGL_lose_context');assert(extension,'Context loss unavailable');
     await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Context restore timed out')),5000);renderer.domElement.addEventListener('webglcontextrestored',()=>{clearTimeout(timer);resolve();},{once:true});renderer.domElement.addEventListener('webglcontextlost',()=>{assert(owner.snapshot().bufferBytes===0,'Lost context retained materials');setTimeout(()=>extension.restoreContext(),50);},{once:true});extension.loseContext();});
    }
    if(frame===20)scene.onAfterRender=()=>{};if(frame===21)scene.onAfterRender=T.Object3D.prototype.onAfterRender;
    if(frame===22){const old=meshes[3].material,m=old.clone();m.onBeforeCompile=old.onBeforeCompile;m.customProgramCacheKey=old.customProgramCacheKey;meshes[3].material=m;materials.add(m);old.dispose();}
    if(frame===23){meshes[4].material.alphaTest=.2;meshes[4].material.needsUpdate=true;}
    if(frame===24)lights[61].layers.set(2);if(frame===25)lights[61].layers.set(0);
    if(frame===26)renderer.shadowMap.enabled=false;if(frame===27)renderer.shadowMap.enabled=true;
    if(frame===28){sun.castShadow=true;lights[14].castShadow=false;}if(frame===31){sun.castShadow=false;lights[14].castShadow=true;}
    const view=frame===18?ortho:camera;
    keyhole.camera=view;keyhole.update(scene,new T.Vector3(),{pitch:.7,distance:30},frame!==4);const beforeMaterials=meshes.map(m=>m.material),beforeHooks=meshes.map(m=>m.onBeforeRender);
    const gl=renderer.getContext(),beforeDraw=renderer.renderBufferDirect,beforeUse=renderer.state.useProgram;
    const packetStarted=performance.now();owner.render(scene,view);window.fixtureProgress={enabled,frame,stage:'drawn',drawMs:performance.now()-packetStarted};assert(renderer.renderBufferDirect===beforeDraw&&renderer.state.useProgram===beforeUse,'Draw hooks leaked');assert(meshes.every((m,i)=>m.material===beforeMaterials[i]&&m.onBeforeRender===beforeHooks[i]),'Source mesh state changed');gl.finish();
    const pixels=new Uint8Array(768*512*4);gl.readPixels(0,0,768,512,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
    const atlases=[];for(const light of [...lights.slice(0,15),sun]){const map=light.shadow.map;if(!map){atlases.push(null);continue;}const bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);atlases.push(await hash(bytes));}
    rows.push({frame,pixels:await hash(pixels),shadows:atlases,draw:{...renderer.info.render},uniforms:owner.snapshot(),keyhole:keyhole.snapshot(),canFlags:meshes.map(m=>keyhole.bindings.get(m)?.can.value)});assert(gl.getError()===0,`GL error frame${frame}`);
   }
   const drawBefore=renderer.renderBufferDirect,useBefore=renderer.state.useProgram;let threw=false;try{owner.render(scene,camera,()=>{throw Error('Authored draw failure');});}catch(error){threw=error.message==='Authored draw failure';}assert(threw&&renderer.renderBufferDirect===drawBefore&&renderer.state.useProgram===useBefore,'Exception leaked renderer hooks');
   screenshot=renderer.domElement.toDataURL('image/png');const buffer=owner.buffer;owner.reset();assert(!buffer||!renderer.getContext().isBuffer(buffer),'Owned point buffer survived reset');results.push({enabled,rows,meshDraws,exceptionRestored:true,after:owner.snapshot()});
  }finally{owner.dispose();target.dispose();keyhole.dispose();shadows.dispose();for(const m of materials)m.dispose();for(const l of [...lights,sun,spot])l.shadow.dispose();geometry.dispose();floor.geometry.dispose();texture.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 const comparisons=results[0].rows.map((a,i)=>{const b=results[1].rows[i];return{frame:i,pixels:a.pixels===b.pixels,shadows:JSON.stringify(a.shadows)===JSON.stringify(b.shadows),calls:a.draw.calls===b.draw.calls,triangles:a.draw.triangles===b.draw.triangles,uniforms:b.uniforms};});
 return{success:comparisons.every(c=>c.pixels&&c.shadows&&c.calls&&c.triangles)&&comparisons.some(c=>c.uniforms.draws>0&&(!compact||c.uniforms.considered>c.uniforms.selected)),comparisons,results,screenshot};
};
