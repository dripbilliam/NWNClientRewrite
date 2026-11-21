import * as THREE from '../node_modules/three/build/three.module.js';
import {createModelLight,installModelLightShaders} from '../src/model_light.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
import {RendererLightSlots,prepareRendererLights} from '../src/renderer_light_slots.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
const assert=(value,message)=>{if(!value)throw Error(message);};
const hash=async bytes=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
installModelLightShaders();
window.runNativeShadowPolicy=async()=>{
 const results=[],reference=[],policyStates=[];
 for(const variant of ['hardware-only','native-policy','selected-reference']){
  const canvas=document.createElement('canvas');document.body.replaceChildren(canvas);const renderer=new THREE.WebGLRenderer({canvas,antialias:false,preserveDrawingBuffer:true});renderer.setSize(1024,768);renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(50,1024/768,.1,100),lights=[],objects=[];scene.background=new THREE.Color(.03,.03,.03);camera.position.set(12,16,24);camera.lookAt(0,0,0);
  const floor=new THREE.Mesh(new THREE.PlaneGeometry(40,40),new THREE.MeshLambertMaterial({color:0xaaaabb}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);objects.push(floor);
  for(let i=0;i<150;i++){const mesh=new THREE.Mesh(new THREE.BoxGeometry(.5,1,.5),new THREE.MeshLambertMaterial({color:0x998877}));mesh.position.set(i%15-7,.5,Math.floor(i/15)-5);mesh.castShadow=true;mesh.receiveShadow=true;scene.add(mesh);objects.push(mesh);}
  for(let i=0;i<30;i++){const light=createModelLight({name:'light'+i,properties:{color:[.2,.15,.12],radius:20,shadowradius:20,multiplier:.2,shadow:1,isdynamic:i===20?1:0,lightpriority:i===20?0:4}});light.position.set(i*.5,3,0);light.shadow.mapSize.set(128,128);light.shadow.camera.near=.1;light.shadow.camera.far=20;light.shadow.intensity=.7;scene.add(light);lights.push(light);}
  const budget=new RendererShadowBudget({renderer,nativeSelection:variant==='native-policy'}),slots=new RendererLightSlots(renderer,()=>{}),traversal=new RendererShadowTraversal(renderer),rows=[];
  try{
   for(let frame=0;frame<12;frame++){
    if(variant==='native-policy'){if(frame===4)budget.maximum=1;if(frame===8)budget.maximum=3;}
    const focus=frame<4?[0,0,0]:[12,0,0];objects[1].position.x=-7+frame*.05;
    if(variant==='selected-reference'){
     scene.updateMatrixWorld();const states=policyStates[frame];for(let i=0;i<lights.length;i++){lights[i].castShadow=states[i].cast;lights[i].shadow.intensity=states[i].intensity;}
     // Reference uses direct Three submission with the same independently
     // machine-code-validated selection; it does not call the policy adapter.
    }else{
     prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,focus,delta:frame===0?.3:.05});
     if(variant==='native-policy')policyStates.push(lights.map(l=>({cast:l.castShadow,intensity:l.shadow.intensity})));
    }
    renderer.render(scene,camera);const gl=renderer.getContext();gl.finish();const pixels=new Uint8Array(1024*768*4);gl.readPixels(0,0,1024,768,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const image=await hash(pixels);
    if(variant==='native-policy')reference.push(pixels);
    if(variant==='selected-reference'){let changed=0;for(let i=0;i<pixels.length;i++)if(pixels[i]!==reference[frame][i])changed++;assert(changed===0,'Selected-reference pixels differ at frame '+frame);}
    assert(gl.getError()===0,'WebGL error');rows.push({frame,image,programs:renderer.info.programs.length,main:{...renderer.info.render},shadow:traversal.snapshot(),selected:lights.filter(l=>l.castShadow).length,slots:slots.state??null});
   }
   assert(lights.every(l=>l.intensity>0),'Illumination was removed');
   if(variant==='native-policy'){assert(rows.every(row=>row.selected<=6&&row.slots.point.shadowCapacity===6),'Unbounded native shadow count');assert(rows.every(row=>row.programs===rows[0].programs),'Shadow setting compiled a new shader profile');}
   const screenshot=variant==='native-policy'?canvas.toDataURL('image/png'):null;budget.reset();slots.dispose();traversal.dispose();assert(budget.states.size===0&&(!budget.native||budget.native.fades.size===0),'Shadow selection owners retained');
   results.push({variant,rows,screenshot,cleanup:true});
  }finally{budget.reset();slots.dispose();traversal.dispose();for(const o of objects){o.geometry.dispose();o.material.dispose();}for(const l of lights)l.shadow.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 assert(results[1].rows[0].shadow.drawCalls<results[0].rows[0].shadow.drawCalls,'No shadow draw reduction');
 return{success:true,scope:'Authored offline GPU workload; selected-reference pixels, bounded maps, live fades and cleanup; not native stencil-volume pixel parity',results};
};
