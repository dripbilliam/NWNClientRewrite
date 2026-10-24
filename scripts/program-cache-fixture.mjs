import * as T from 'three';
import {RendererModelPreparation} from '../src/renderer_model_preparation.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
const check=(ok,message)=>{if(!ok)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
window.runProgramCacheFixture=async()=>{
 const results=[];let screenshot;
 for(const {cachePrograms,programLimit=128} of [{cachePrograms:false},{cachePrograms:true},{cachePrograms:true,programLimit:12}]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(640,480,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const gl=renderer.getContext(),create=gl.createProgram.bind(gl);let creations=0;gl.createProgram=()=>{creations++;return create();};
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(45,4/3,.1,100);camera.position.set(15,17,21);camera.lookAt(0,0,0);
  const adapter=new RendererShadowTraversal(renderer,{instances:true}),owner=new RendererModelPreparation({renderer,scene,camera,shadowInstances:true,cachePrograms,programLimit}),rows=[],errors=[],retired=[];renderer.debug.onShaderError=()=>errors.push('Shader compile/link failed');
  try{
   const visitArea=async kind=>{
    const root=new T.Group(),geometry=new T.BoxGeometry(1,2,1),texture=new T.DataTexture(new Uint8Array([220,180,100,255,70,90,180,0,100,190,90,255,240,240,200,255]),2,2);texture.needsUpdate=true;
    const material=new T.MeshLambertMaterial({color:0x998877,map:kind==='a'?texture:null,alphaTest:kind==='a'?.2:0,flatShading:kind==='b',side:T.DoubleSide}),tint={value:new T.Vector3(.8,.9,1)};
    retired.push({texture:new WeakRef(texture),geometry:new WeakRef(geometry),tint:new WeakRef(tint)});
    // Shared source uniforms stay live. A retired cache clone must drop its
    // references, not clear/mutate this shared object or the source callback.
    const hook=shader=>{shader.uniforms.authoredTint=tint;shader.fragmentShader='uniform vec3 authoredTint;\n'+shader.fragmentShader.replace('vec4 diffuseColor = vec4( diffuse, opacity );','vec4 diffuseColor = vec4( diffuse * authoredTint, opacity );');};material.onBeforeCompile=hook;material.customProgramCacheKey=()=> 'authored-retained-tint-v1';
    const particleMaterial=new T.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{map:{value:texture},tint:{value:tint.value}},vertexShader:'varying vec2 authoredUv;void main(){authoredUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',fragmentShader:'uniform sampler2D map;uniform vec3 tint;varying vec2 authoredUv;void main(){gl_FragColor=vec4(texture2D(map,authoredUv).rgb*tint,.4);}'}),particle=new T.Mesh(geometry,particleMaterial);particle.position.set(0,4,0);root.add(particle);retired.at(-1).particleMaterial=new WeakRef(particleMaterial);
    for(let i=0;i<24;i++){const mesh=new T.Mesh(geometry,material);mesh.position.set(i%6*2-5,1,Math.floor(i/6)*2-3);mesh.castShadow=mesh.receiveShadow=true;root.add(mesh);}
    const floor=new T.Mesh(new T.PlaneGeometry(30,30),new T.MeshLambertMaterial({color:0x778899}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;root.add(floor);
    const ambient=new T.AmbientLight(0xffffff,.4),point=new T.PointLight(0xffffff,30,40),sun=new T.DirectionalLight(0xffffff,1);point.position.set(0,5,0);sun.position.set(8,12,7);sun.shadow.camera.left=sun.shadow.camera.bottom=-12;sun.shadow.camera.right=sun.shadow.camera.top=12;for(const light of [point,sun]){light.castShadow=true;light.shadow.mapSize.set(128,128);}scene.add(root,ambient,point,sun);scene.fog=kind==='b'?new T.FogExp2(0x8899aa,.006):null;scene.updateMatrixWorld();camera.updateMatrixWorld();
    const before=creations,at=performance.now();await owner.prepareArea(root);const preparationMs=performance.now()-at,newPreparationPrograms=creations-before,frames=[];
    for(let frame=0;frame<3;frame++){
     const count=creations;renderer.render(scene,camera);const pixels=new Uint8Array(640*480*4);gl.readPixels(0,0,640,480,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const atlases=[];for(const light of [point,sun]){const map=light.shadow.map,bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);atlases.push(await hash(bytes));}frames.push({pixels:await hash(pixels),atlases,newPrograms:creations-count});check(gl.getError()===0,'WebGL error');
    }
    screenshot=renderer.domElement.toDataURL('image/png');owner.releaseArea(root);await Promise.resolve();await Promise.resolve();check(material.map===(kind==='a'?texture:null)&&material.onBeforeCompile===hook,'Cache modified source material');check(tint.value.equals(new T.Vector3(.8,.9,1)),'Cache modified live uniform');
    if(owner.programCache)for(const retained of owner.programCache.entries.keys()){
     check(retained.map==null&&Object.keys(retained.userData).length===0,'Retained source texture or metadata');check(Object.keys(renderer.properties.get(retained)).every(key=>key==='programs'),'Retained area renderer state');check(retained.onBeforeCompile===T.Material.prototype.onBeforeCompile,'Retained shader owner closure');
    }
    adapter.reset();scene.remove(root,ambient,point,sun);geometry.dispose();material.dispose();particleMaterial.dispose();floor.geometry.dispose();floor.material.dispose();texture.dispose();point.shadow.dispose();sun.shadow.dispose();
    renderer.render(scene,camera); // Retire the render list's last source refs.
    // The preparation owner retains its one-pixel shadow-output target until
    // final disposal. Every actual area texture and shadow atlas must retire.
    check(renderer.info.memory.geometries===0,'Area geometry survived teardown');check(renderer.info.memory.textures===1,'Area texture survived teardown: '+renderer.info.memory.textures);
    rows.push({kind,preparationMs,newPreparationPrograms,frames,afterRelease:owner.snapshot(),gpuMemory:{...renderer.info.memory},residentPrograms:renderer.info.programs.length});
    if(owner.programCache)check(owner.programCache.snapshot().references<=programLimit,'Program lease reference budget exceeded');
   };
   for(const kind of ['a','b','a'])await visitArea(kind);
   const extension=gl.getExtension('WEBGL_lose_context');check(extension,'Context-loss fixture unavailable');
   await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Context restoration timed out')),8000);renderer.domElement.addEventListener('webglcontextrestored',()=>{clearTimeout(timer);resolve();},{once:true});renderer.domElement.addEventListener('webglcontextlost',()=>{if(owner.programCache)check(owner.programCache.snapshot().materials===0,'Lost context retained program leases');setTimeout(()=>extension.restoreContext(),50);},{once:true});extension.loseContext();});
   check(renderer.info.programs.length===0,'Restored context retained old programs');await visitArea('a');
   check(typeof globalThis.gc==='function','Explicit fixture GC unavailable');for(let i=0;i<3;i++){await new Promise(resolve=>setTimeout(resolve,10));globalThis.gc();}
   const collected=retired.map(row=>({texture:!row.texture.deref(),geometry:!row.geometry.deref(),tint:!row.tint.deref(),particleMaterial:!row.particleMaterial.deref()}));check(collected.every(row=>row.texture&&row.geometry&&row.tint&&row.particleMaterial),'Retired source JavaScript owners survived cache retention: '+JSON.stringify(collected));
   owner.resetPrograms();check(renderer.info.programs.length===0,'Programs survived explicit session reset');results.push({cachePrograms,programLimit,rows,collected,afterReset:owner.snapshot()});check(!errors.length,'Shader compilation errors');owner.dispose();check(renderer.info.memory.textures===0,'Preparation target survived final disposal');
  }finally{owner.dispose();adapter.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 const [control,cached,evicted]=results,equalPixels=results.slice(1).every(candidate=>control.rows.every((row,i)=>row.frames.every((frame,j)=>frame.pixels===candidate.rows[i].frames[j].pixels&&JSON.stringify(frame.atlases)===JSON.stringify(candidate.rows[i].frames[j].atlases))));
 return{success:equalPixels&&control.rows[2].newPreparationPrograms>0&&cached.rows[2].newPreparationPrograms===0&&evicted.rows[2].newPreparationPrograms>0&&results.every(result=>result.rows.every(row=>row.frames.every(frame=>frame.newPrograms===0))),equalPixels,results,screenshot,scope:'Authored A/B/A scene recreation, bounded LRU eviction, fog/material/custom shader variants, context restoration, new texture/geometry/uniform owners and actual GC, real WebGL programs and point/directional shadows; no server joins or gameplay FPS acceptance'};
};
