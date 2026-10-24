import * as T from 'three';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {RendererLightSlots,prepareRendererLights} from '../src/renderer_light_slots.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
const renderer=new T.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});document.body.append(renderer.domElement);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
const scene=new T.Scene();scene.background=new T.Color('#203030');const camera=new T.PerspectiveCamera(42,1,.1,300);camera.position.set(24,22,30);camera.lookAt(0,0,0);
const geometry=new T.BoxGeometry(1,2,1),material=new T.MeshLambertMaterial({color:'#99b8ba'}),floorMaterial=new T.MeshLambertMaterial({color:'#858376'}),floor=new T.Mesh(new T.PlaneGeometry(140,140),floorMaterial);floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
const moving=new T.Mesh(geometry,material);moving.castShadow=true;moving.position.set(2,1,1);scene.add(moving);
for(let x=-6;x<6;x++)for(let z=-6;z<6;z++){
 const tile=new T.Group();tile.position.set(x*10,0,z*10);scene.add(tile);
 for(let j=0;j<30;j++){const node=new T.Group(),mesh=new T.Mesh(geometry,material);node.position.set((j%6)*1.3,1,Math.floor(j/6)*1.3);mesh.castShadow=true;node.add(mesh);tile.add(node);}
}
const lights=[];for(let i=0;i<6;i++){const light=new T.PointLight(0xffecc5,18,16,1);light.position.set((i%3-1)*15,8,(Math.floor(i/3)-.5)*15);light.castShadow=true;light.shadow.mapSize.set(128,128);scene.add(light);lights.push(light);}
scene.add(new T.AmbientLight(0x445050,1));const original=renderer.shadowMap.render;let adapter;
const enable=value=>{if(value&&!adapter)adapter=new RendererShadowTraversal(renderer);if(!value&&adapter){adapter.dispose();adapter=null;}};
const pixels=()=>{const gl=renderer.getContext(),p=new Uint8Array(renderer.domElement.width*renderer.domElement.height*4);gl.readPixels(0,0,renderer.domElement.width,renderer.domElement.height,gl.RGBA,gl.UNSIGNED_BYTE,p);return p;};
const shadows=()=>lights.map(l=>{const target=l.shadow.map,p=new Uint8Array(target.width*target.height*4);renderer.readRenderTargetPixels(target,0,0,target.width,target.height,p);return p;});
function difference(a,b){if(a.length!==b.length)throw Error('Readback length changed');let count=0,max=0;for(let i=0;i<a.length;i++){const d=Math.abs(a[i]-b[i]);if(d)count++;max=Math.max(max,d);}return{count,max};}
function assertSame(a,b,what){const d=difference(a,b);if(d.count)throw Error(what+' changed '+JSON.stringify(d));return d;}
window.runShadowTraversalFixture=async()=>{
 const comparisons=[];
 for(const size of [[1084,673],[3100,1192]]){
  renderer.setSize(...size);camera.aspect=size[0]/size[1];camera.updateProjectionMatrix();
  for(const state of ['initial','moved','hidden','deformed','removed']){
   moving.visible=state!=='hidden';moving.position.x=state==='initial'?2:-10;
   if(state==='deformed'){geometry.attributes.position.setY(0,7);geometry.attributes.position.needsUpdate=true;geometry.computeBoundingSphere();}
   if(state==='removed')scene.remove(moving);else if(!moving.parent)scene.add(moving);
   enable(false);renderer.render(scene,camera);const reference=pixels(),referenceShadows=shadows();
   enable(true);renderer.render(scene,camera);renderer.render(scene,camera);
   const image=assertSame(reference,pixels(),state+' color'),maps=shadows().map((p,i)=>assertSame(referenceShadows[i],p,state+' shadow '+i));comparisons.push({size,state,image,maps,traversal:adapter.snapshot()});
  }
 }
 const times={};for(const optimized of [false,true]){
  enable(optimized);for(let i=0;i<3;i++)renderer.render(scene,camera);const samples=[];
  for(let i=0;i<8;i++){const start=performance.now();renderer.render(scene,camera);samples.push(performance.now()-start);}times[optimized?'optimized':'reference']=samples;
 }
 const screenshot=renderer.domElement.toDataURL('image/png');enable(false);if(renderer.shadowMap.render!==original)throw Error('Shadow renderer was not restored');
 const rotation=[],slots=new RendererLightSlots(renderer,()=>{}),budget=new RendererShadowBudget({renderer,report:()=>{}}),selection={update(){return{total:lights.length,disabled:0,admitted:lights.filter(l=>l.layers.mask).length,maxLights:128};}};
 for(const count of [2,6,1,4]){lights.forEach((l,i)=>{l.layers.mask=i<count?1:0;});renderer.render(scene,camera);}
 // One sphere's view becomes another as a real camera turns. Change which
 // real lights are admitted, then compare to the unpadded renderer each time.
 for(const count of [2,6,1,4,6,2]){
  slots.group.removeFromParent();lights.forEach((l,i)=>{l.layers.mask=i<count?1:0;});renderer.render(scene,camera);const reference=pixels(),referenceShadows=shadows();
  const prepared=prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection});renderer.render(scene,camera);const image=difference(reference,pixels()),maps=shadows().map((p,i)=>assertSame(referenceShadows[i],p,'rotation shadow '+i));
  // Changing GLSL loop counts can round a final 8-bit color by one unit. Keep
  // that explicitly bounded/reported; shadow maps must remain byte-exact.
  if(image.max>1||image.count>reference.length*.00001)throw Error('Rotation image exceeded rounding tolerance '+JSON.stringify(image));
  rotation.push({count,image,maps,capacity:prepared.slots.point,programs:renderer.info.programs.length});
 }
 if(new Set(rotation.map(r=>r.programs)).size!==1)throw Error('Camera admission compiled another shader profile');slots.dispose();
 return{passed:true,comparisons,times,rotation,screenshot,gpu:renderer.getContext().getParameter(renderer.getContext().RENDERER)};
};
