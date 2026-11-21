import * as T from 'three';
import {RendererLightSlots,prepareRendererLights,renderPreparedScene} from '../src/renderer_light_slots.js';
import {RendererLightSelection} from '../src/renderer_light_selection.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {createModelLight,installModelLightShaders} from '../src/model_light.js';
const check=(value,message)=>{if(!value)throw Error(message);};
window.runLightCapacityFixture=async({shadowSize=64,movingShadows=false}={})=>{
 installModelLightShaders();const width=3100,height=1121,renderer=new T.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});renderer.setSize(width,height);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;document.body.append(renderer.domElement);
 const errors=[];renderer.debug.onShaderError=()=>errors.push('shader compile/link failure');
 const gl=renderer.getContext(),scene=new T.Scene(),camera=new T.OrthographicCamera(-20,20,20*height/width,-20*height/width,.1,150);camera.position.set(0,55,0);camera.up.set(0,0,-1);camera.lookAt(0,0,0);scene.background=new T.Color(0x19211e);scene.add(new T.AmbientLight(0x333333));
 //1275 main draws and about17800 triangles; synthetic data only.
 const box=new T.BoxGeometry(.9,.6,.9).toNonIndexed(),quad=new T.PlaneGeometry(.9,.9).rotateX(-Math.PI/2).translate(0,.31,0).toNonIndexed(),geometry=new T.BufferGeometry();
 for(const key of ['position','normal','uv']){const a=box.attributes[key],b=quad.attributes[key],values=new Float32Array(a.array.length+b.array.length);values.set(a.array);values.set(b.array,a.array.length);geometry.setAttribute(key,new T.BufferAttribute(values,a.itemSize));}geometry.computeBoundingSphere();box.dispose();quad.dispose();
 const texture=new T.DataTexture(new Uint8Array([160,180,120,255]),1,1);texture.needsUpdate=true;const materials=[],meshes=[];
 for(let i=0;i<1274;i++){const material=new T.MeshLambertMaterial({map:texture,alphaTest:.035});materials.push(material);const mesh=new T.Mesh(geometry,material);mesh.position.set((i%36)-17.5,.3,(Math.floor(i/36)-17.5)*.36);mesh.castShadow=i%3===0;mesh.receiveShadow=true;scene.add(mesh);meshes.push(mesh);}
 const floorMaterial=new T.MeshLambertMaterial({map:texture}),floorGeometry=new T.PlaneGeometry(40,16),floor=new T.Mesh(floorGeometry,floorMaterial);floor.rotation.x=-Math.PI/2;floor.position.y=-.02;floor.receiveShadow=true;scene.add(floor);
 const lights=[];for(let i=0;i<42;i++){const light=createModelLight({name:'fixture'+i,properties:{color:[.23+(i%3)*.03,.21,.2],radius:8,multiplier:.3,shadow:i<15?1:0}},l=>l.shadow.mapSize.set(shadowSize,shadowSize));light.position.set((i%7-3)*5,3,(Math.floor(i/7)-2.5)*2);scene.add(light);lights.push(light);}
 const selection=new RendererLightSelection(),budget=new RendererShadowBudget({renderer,report:()=>{}}),traversal=new RendererShadowTraversal(renderer),phases=[],pictures=[];let slots;
 const draw=()=>{const prepared=prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus:[0,0,0]});renderPreparedScene(renderer,scene,camera,prepared);return prepared;};
 const pixels=()=>{const data=new Uint8Array(width*height*4);gl.readPixels(0,0,width,height,gl.RGBA,gl.UNSIGNED_BYTE,data);return data;};
 try{
  const scenarios=movingShadows?[{capacity:128,moving:true,force:false},{capacity:128,moving:true,force:true},{capacity:128,moving:true,force:false}]:[128,64,128,64].map(capacity=>({capacity}));
  for(const scenario of scenarios){const {capacity,moving,force}=scenario;
   const animate=step=>{if(moving){meshes[0].position.y=.3+Math.sin(step*.3)*.1;meshes[0].rotation.y=step*.05;meshes[3].position.y=.3+Math.cos(step*.3)*.1;}if(force)for(const light of lights)if(light.castShadow)light.shadow.needsUpdate=true;};
   slots?.dispose();slots=new RendererLightSlots(renderer,()=>{});
   // Deliberate fixture intervention isolates declared shader capacity. No
   // production reserve policy is changed by this benchmark.
   slots.capacities.set('point',capacity);draw();const compileStart=performance.now();await renderer.compileAsync(scene,camera);const compileMs=performance.now()-compileStart;
   for(let i=0;i<4;i++){await new Promise(requestAnimationFrame);animate(i);draw();gl.finish();}
   const initialPrograms=renderer.info.programs.length,times=[],shadowFrames=[];let lighting;
   for(let i=0;i<24;i++){await new Promise(requestAnimationFrame);animate(i);const at=performance.now();lighting=draw();gl.finish();times.push(performance.now()-at);shadowFrames.push(traversal.snapshot());}
   pictures.push(pixels());check(lighting.slots.point.capacity===capacity,'Capacity intervention failed');check(lighting.selection.admitted===42,'Real light admission changed');check(lighting.shadows.admitted===15,'Real shadow admission changed');check(renderer.info.render.calls===1275,'Dense fixture did not draw every object');check(initialPrograms===renderer.info.programs.length,'Steady draw compiled new shaders');
   if(moving){check(shadowFrames.every(f=>f.renderedLights>0),'Moving casters did not invalidate shadows');check(shadowFrames.every(f=>force?f.renderedLights===15:f.reusedLights>0),'Shadow reference/cache path did not execute');}
   phases.push({capacity,moving:Boolean(moving),forcedShadowRefresh:Boolean(force),compileMs,completedFrameMs:times,programs:initialPrograms,main:{...renderer.info.render},shadow:traversal.snapshot(),shadowFrames,lighting});
  }
  let changed=0,max=0;for(const pic of pictures.slice(1))for(let i=0;i<pic.length;i++){const delta=Math.abs(pic[i]-pictures[0][i]);changed+=Number(delta!==0);max=Math.max(max,delta);}check(changed===0,'Declared zero-light slots changed pixels: '+JSON.stringify({changed,max}));check(!errors.length&&gl.getError()===gl.NO_ERROR,'GPU error');
  const debug=gl.getExtension('WEBGL_debug_renderer_info'),screenshot=renderer.domElement.toDataURL('image/png');
  return{scope:'Isolated renderer experiment: synthetic dense1275-draw/42-real-light/15-shadow scene; production admission and shaders unchanged. Moving-shadow mode compares cached maps with a forced full refresh at identical final caster poses. This is not live-server/full-native-renderer acceptance.',width,height,shadowSize,movingShadows,phases,changedBytes:changed,maxByteDelta:max,errors,gpu:debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),screenshot};
 }finally{slots?.dispose();selection.dispose();traversal.dispose();for(const m of materials)m.dispose();floorMaterial.dispose();geometry.dispose();floorGeometry.dispose();texture.dispose();renderer.dispose();}
};
