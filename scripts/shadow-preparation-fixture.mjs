import * as T from 'three';
import {RendererModelPreparation} from '../src/renderer_model_preparation.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
const check=(ok,message)=>{if(!ok)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
window.runShadowPreparationFixture=async()=>{
 const results=[];let screenshot;
 for(const shadowInstances of [false,true]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(640,480,false);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const scene=new T.Scene(),root=new T.Group(),camera=new T.PerspectiveCamera(45,4/3,.1,100),geometry=new T.BoxGeometry(1,2,1),texture=new T.DataTexture(new Uint8Array([220,180,100,255,70,90,180,0,100,190,90,255,240,240,200,255]),2,2);texture.needsUpdate=true;
  const materials=[new T.MeshLambertMaterial({color:0x998877}),new T.MeshLambertMaterial({map:texture,alphaTest:.2,side:T.DoubleSide})];
  for(let i=0;i<24;i++){const mesh=new T.Mesh(geometry,materials[i%2]);mesh.position.set(i%6*2-5,1,Math.floor(i/6)*2-3);mesh.castShadow=mesh.receiveShadow=true;root.add(mesh);}
  const floor=new T.Mesh(new T.PlaneGeometry(30,30),new T.MeshLambertMaterial({color:0x778899}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;root.add(floor);scene.add(root,new T.AmbientLight(0xffffff,.4));
  const point=new T.PointLight(0xffffff,30,40),sun=new T.DirectionalLight(0xffffff,1);point.position.set(0,5,0);sun.position.set(8,12,7);sun.shadow.camera.left=sun.shadow.camera.bottom=-12;sun.shadow.camera.right=sun.shadow.camera.top=12;for(const light of [point,sun]){light.castShadow=true;light.shadow.mapSize.set(128,128);scene.add(light);}
  camera.position.set(15,17,21);camera.lookAt(0,0,0);scene.updateMatrixWorld();camera.updateMatrixWorld();
  const adapter=new RendererShadowTraversal(renderer,{instances:true}),owner=new RendererModelPreparation({renderer,scene,camera,shadowInstances}),errors=[];renderer.debug.onShaderError=()=>errors.push('Shader compile/link failed');
  try{
   const started=performance.now();await owner.prepareArea(root);const preparationMs=performance.now()-started,prepared=renderer.info.programs.length,frames=[];
   for(let i=0;i<4;i++){const before=renderer.info.programs.length,at=performance.now();renderer.render(scene,camera);const drawMs=performance.now()-at;const gl=renderer.getContext(),pixels=new Uint8Array(640*480*4);gl.readPixels(0,0,640,480,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const atlases=[];for(const light of [point,sun]){const map=light.shadow.map,bytes=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,bytes);atlases.push(await hash(bytes));}frames.push({newPrograms:renderer.info.programs.length-before,drawMs,pixels:await hash(pixels),atlases,shadow:adapter.snapshot()});check(gl.getError()===0,'WebGL error');}
   screenshot=renderer.domElement.toDataURL('image/png');owner.releaseArea(root);await Promise.resolve();await Promise.resolve();check(owner.snapshot().activeAreas===0,'Area owner retained');check(!errors.length,'Shader errors');results.push({shadowInstances,preparationMs,prepared,frames,after:owner.snapshot()});
  }finally{owner.dispose();adapter.dispose();geometry.dispose();floor.geometry.dispose();floor.material.dispose();for(const material of materials)material.dispose();for(const light of [point,sun])light.shadow.dispose();texture.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 const a=results[0],b=results[1],equalPixels=a.frames.every((row,i)=>row.pixels===b.frames[i].pixels&&JSON.stringify(row.atlases)===JSON.stringify(b.frames[i].atlases));
 return{results,equalPixels,fixed:b.frames.every(row=>row.newPrograms===0),controlReproduces:a.frames.some(row=>row.newPrograms>0),screenshot,scope:'Authored static scene, actual Three/WebGL shader compile and production shadow instancing adapter; no networking or original binary access'};
};
