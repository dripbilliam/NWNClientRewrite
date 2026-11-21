import * as T from 'three';
import {RendererLightSlots,prepareRendererLights,renderPreparedScene} from '../src/renderer_light_slots.js';
import {RendererLightSelection} from '../src/renderer_light_selection.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
window.runFrameMatricesFixture=async()=>{
 const renderer=new T.WebGLRenderer({preserveDrawingBuffer:true,antialias:false});renderer.setSize(512,384);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
 const errors=[];renderer.debug.onShaderError=()=>errors.push('shader error');
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(45,512/384,.1,100);camera.position.set(8,9,15);camera.lookAt(0,0,0);scene.add(new T.AmbientLight(0x333333));
 const parent=new T.Group(),mesh=new T.Mesh(new T.BoxGeometry(2,3,2),new T.MeshLambertMaterial({color:0x88bbaa}));mesh.position.y=1.5;mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);scene.add(parent);
 const floor=new T.Mesh(new T.PlaneGeometry(30,30),new T.MeshLambertMaterial({color:0x888888}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
 const lights=[];for(let i=0;i<6;i++){const light=new T.PointLight(0x9999ff,6,30);light.position.set(i-3,6,i%2?5:-5);light.castShadow=i<2;light.shadow.mapSize.set(64,64);scene.add(light);lights.push(light);}
 const options={shadowBudget:new RendererShadowBudget({renderer,report:()=>{}}),lightSlots:new RendererLightSlots(renderer,()=>{}),lightSelection:new RendererLightSelection(),focus:[0,0,0]};
 const gl=renderer.getContext(),pixels=()=>{const data=new Uint8Array(512*384*4);gl.readPixels(0,0,512,384,gl.RGBA,gl.UNSIGNED_BYTE,data);return data;},results=[];
 let passes=0;const update=scene.updateMatrixWorld;scene.updateMatrixWorld=function(...args){passes++;return update.apply(this,args);};
 for(let frame=0;frame<8;frame++){
  parent.position.x=Math.sin(frame)*3;parent.rotation.y=frame*.3;mesh.scale.x=frame%2?-1:1;lights[0].position.x=frame-4;
  const before=passes;prepareRendererLights(scene,camera,options);renderer.render(scene,camera);const reference=pixels(),referencePasses=passes-before;
  const beforeOptimized=passes,prepared=prepareRendererLights(scene,camera,options);renderPreparedScene(renderer,scene,camera,prepared);const optimized=pixels();let changed=0;
  for(let i=0;i<reference.length;i++)if(reference[i]!==optimized[i])changed++;
  const optimizedPasses=passes-beforeOptimized;if(changed||referencePasses!==2||optimizedPasses!==1||scene.matrixWorldAutoUpdate!==true)throw Error(JSON.stringify({frame,changed,referencePasses,optimizedPasses}));
  results.push({frame,changed,referencePasses,optimizedPasses});
 }
 const error=gl.getError();if(error||errors.length)throw Error(JSON.stringify({error,errors}));options.lightSelection.dispose();options.lightSlots.dispose();renderer.dispose();return{results,error,errors};
};
