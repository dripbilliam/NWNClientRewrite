import * as T from 'three';
import {RendererLightSelection} from '../src/renderer_light_selection.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import {RendererLightSlots,prepareRendererLights,renderPreparedScene} from '../src/renderer_light_slots.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {installCompactLightLoops} from '../src/renderer_light_loops.js';
import {installModelLightShaders} from '../src/model_light.js';
import {CameraKeyholePresentation} from '../src/camera_keyhole_shader.js';
import {TargetPreviewShader} from '../src/target_preview_shader.js';
import {createModelEmitter,ModelParticlePresentation} from '../src/model_particles.js';
import {ResourceWorkerPool} from '../src/resource_worker_pool.js';
import {sampleParticleVertices} from '../src/particle_vertex_batch.js';
const percentile=(a,p)=>a.toSorted((a,b)=>a-b)[Math.min(a.length-1,Math.floor(a.length*p))],summary=a=>({meanMs:a.reduce((n,v)=>n+v,0)/a.length,p50Ms:percentile(a,.5),p95Ms:percentile(a,.95),maxMs:Math.max(...a)});
window.runHeavyRendererFixture=async({native=false,legacySlots=false,compact=false,particles=false,workerBundle=null}={})=>{
 installModelLightShaders();if(compact)installCompactLightLoops();
 const renderer=new T.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});renderer.setSize(3440,1369);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;document.body.append(renderer.domElement);
 const errors=[];renderer.debug.onShaderError=()=>errors.push('shader error');const scene=new T.Scene(),camera=new T.PerspectiveCamera(55,3440/1369,.1,300);camera.position.set(0,68,76);camera.lookAt(0,0,0);scene.background=new T.Color('#17232a');scene.add(new T.AmbientLight(0x222222));
 const geometry=new T.CylinderGeometry(.45,.65,1.8,8),materials=Array.from({length:32},(_,i)=>new T.MeshLambertMaterial({color:new T.Color().setHSL(i/32,.3,.4)})),moving=[];
 for(let i=0;i<1500;i++){
  const model=new T.Group();model.userData.nativeStaticTile=true;model.position.set((i%50)*1.8-45,.9,Math.floor(i/50)*1.8-27);scene.add(model);let parent=model;for(let j=0;j<3;j++){const part=new T.Group();parent.add(part);parent=part;}
  const mesh=new T.Mesh(geometry,materials[i%32]);mesh.userData.nativeModelMesh=true;mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);if(i%251===0)moving.push(model);
 }
 const floor=new T.Mesh(new T.PlaneGeometry(110,70),new T.MeshLambertMaterial({color:0x777766}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
 for(let i=0;i<63;i++){
  const light=new T.PointLight(0xffddbb,1.2,13,1);light.position.set((i%9)*11-44,5,Math.floor(i/9)*8-24);light.castShadow=true;light.shadow.mapSize.set(512,512);light.shadow.camera.near=.1;light.shadow.camera.far=13;light.shadow.bias=-.0002;light.shadow.normalBias=.025;light.userData.mdlLight={radius:13,multiplier:1.2,color:[1,.8,.6],isdynamic:0};light.userData.mdlLightShadowRequested=true;scene.add(light);
 }
 let vertexWorkers,workersEnabled=false;const workerWarmStarted=performance.now();if(workerBundle){vertexWorkers=new ResourceWorkerPool({size:4,createWorker:()=>new Worker(workerBundle,{type:'module'})});await Promise.all(Array.from({length:4},()=>vertexWorkers.run('particle-vertices',{buffer:new ArrayBuffer(0),frames:[]})));}const workerWarmMs=performance.now()-workerWarmStarted;
 let particlePresentation,particleTexture,particleRoot;const particleTimes=[];if(particles){
  particleRoot=new T.Group();scene.add(particleRoot);particleTexture=new T.DataTexture(new Uint8Array([255,255,255,255]),1,1);particleTexture.needsUpdate=true;particlePresentation=new ModelParticlePresentation({camera,seed:17,vertexPool:()=>workersEnabled?vertexWorkers:null,report:code=>{if(code==='particle.runtime-unavailable')errors.push(code);}});
  for(let i=0;i<80;i++){const model=new T.Group();model.userData.mdlRoot='authored-heavy-particles';model.position.set((i%10)*8-36,1,Math.floor(i/10)*6-21);particleRoot.add(model);const parent=new T.Group();model.add(parent);parent.add(createModelEmitter({name:'authored-emitter',properties:{texture:'fixture',update:'Fountain',render:['Normal','Billboard_to_World_Z','Motion_Blur','Aligned_to_Particle_Dir'][i%4],blend:'Lighten',birthrate:80,lifeexp:2,sizestart:.3,sizeend:.6,colorstart:[1,.5,.25],colorend:[.2,.2,.1],alphastart:.6,alphaend:0,xgrid:1,ygrid:1,velocity:1,randvel:.5,affectedbywind:'false'}},new Map([['fixture',particleTexture]]),'authored-heavy-particles'));}
  for(let i=0;i<150;i++)particlePresentation.update(particleRoot,1/60);
 }
 const lightSelection=new RendererLightSelection(),shadowBudget=new RendererShadowBudget({renderer,report(){}}),lightSlots=new RendererLightSlots(renderer,()=>{}),traversal=new RendererShadowTraversal(renderer),timings=[],lightTimes=[],drawTimes=[],samples=[];
 if(legacySlots)lightSlots.capacities.set('point',193);
 let keyhole,target;if(native){const resolver={getResource:async(name,type)=>{const r=await window.creationFixture.resource(name,type);if(!r.ok)throw Error(r.message);return r.value;}};keyhole=await new CameraKeyholePresentation({renderer,camera}).load(resolver);keyhole.bind(scene);target=await new TargetPreviewShader().load(resolver);target.bind(scene);}
 const preparation=()=>{keyhole?.update(scene,new T.Vector3(0,.9,0),{pitch:50,distance:100});target?.bind(scene);return prepareRendererLights(scene,camera,{lightSelection,shadowBudget,lightSlots,focus:[0,0,0]});};let prepared=preparation(),start=performance.now();await renderer.compileAsync(scene,camera);const compileMs=performance.now()-start;renderPreparedScene(renderer,scene,camera,prepared);workersEnabled=true;const gaps=[];let previousEnd=null;
 for(let i=0;i<72;i++){
  moving.forEach((model,j)=>model.rotation.y=i*.01+j*.2);start=performance.now();particlePresentation?.update(particleRoot,1/60);const particleEnd=performance.now();prepared=preparation();const lightEnd=performance.now();renderPreparedScene(renderer,scene,camera,prepared);const end=performance.now();
  if(i>=12){timings.push(end-start);particleTimes.push(particleEnd-start);lightTimes.push(lightEnd-particleEnd);drawTimes.push(end-lightEnd);if(previousEnd!==null)gaps.push(end-previousEnd);samples.push({draws:renderer.info.render.calls,triangles:renderer.info.render.triangles,shadows:traversal.snapshot()});}previousEnd=end;
  await new Promise(requestAnimationFrame);
 }
 const measuredWorkers=particlePresentation?.vertexSnapshot();if(vertexWorkers&&particlePresentation?.vertexPreparation){await particlePresentation.vertexPreparation.work;const items=[...particlePresentation.entries.values()].filter(entry=>!entry.failed).map(entry=>({entry,input:sampleParticleVertices(entry.e,{...entry.providers,cameraQuaternion:()=>{const q=camera.getWorldQuaternion(new T.Quaternion()),b=new T.Quaternion().setFromAxisAngle(new T.Vector3(1,0,0),-Math.PI/2).invert().multiply(q);return[b.w,b.x,b.y,b.z];}})})).filter(item=>item.input);particlePresentation.vertexPreparation.submit(items);await particlePresentation.vertexPreparation.work;prepared=preparation();renderPreparedScene(renderer,scene,camera,prepared);}
 const gl=renderer.getContext(),info=gl.getExtension('WEBGL_debug_renderer_info'),pixels=new Uint8Array(3440*1369*4);gl.readPixels(0,0,3440,1369,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',pixels))).map(b=>b.toString(16).padStart(2,'0')).join('');
 const result={success:!errors.length,scope:'Authored offline renderer throughput fixture, not original-game or whole-client FPS',nativeShaders:native,legacySlots,compactLoops:compact,resolution:[3440,1369],meshes:1501,pointLights:63,compileMs,workerWarmMs,vertexWorkers:measuredWorkers,workerPool:vertexWorkers?.snapshot(),frame:summary(timings),frameGap:summary(gaps),particles:summary(particleTimes),particleState:particlePresentation?.snapshot(),lights:summary(lightTimes),render:summary(drawTimes),last:samples.at(-1),slots:lightSlots.state,gpu:info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):null,programs:renderer.info.programs.length,errors,pixelHash:digest,screenshot:renderer.domElement.toDataURL('image/png')};
 target?.dispose();keyhole?.dispose();particlePresentation?.dispose();vertexWorkers?.dispose();particleTexture?.dispose();traversal.dispose();lightSelection.dispose();lightSlots.dispose();scene.traverse(o=>o.shadow?.map?.dispose());geometry.dispose();materials.forEach(m=>m.dispose());floor.geometry.dispose();floor.material.dispose();renderer.dispose();return result;
};
