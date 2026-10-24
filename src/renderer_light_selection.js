import {Frustum,Matrix4,Vector3} from 'three';
const f=Math.fround;

// Original GetLightAdjustedRadius07f480 and PrioritizeLights07ff60. Runtime
// Part RGB is authored sRGB, not Three's already-linearized light.color.
export function nativeLightRadius(light,{colorAdjusted=false,radiusScale=1}={}){
 let radius=f(light.radius);if(radius<1000){radius=f(radius*f(light.multiplier));if(colorAdjusted){const maximum=Math.max(...light.color.map(f));if(maximum>1)radius=f(radius*maximum);radius=f(f(radiusScale)*radius);}}return radius;
}
export function nativeLightPriority(light,focus,{onlyOwner=null}={}){
 const delta=light.position.map((v,i)=>f(f(v)-f(focus[i]))),square=f(f(f(delta[1]*delta[1])+f(delta[0]*delta[0]))+f(delta[2]*delta[2])),distance=f(Math.sqrt(square)),maximum=Math.max(...light.color.map(v=>Math.abs(f(v))));
 if(maximum<=0||light.radius<=0||light.multiplier<=0)return{distance,priority:100000};
 if(onlyOwner!==null&&light.owner===onlyOwner)return{distance,priority:-1};
 const authored=light.priorityOverride|0,priority=authored||light.priority|0,energy=light.fading?f(f(f(light.multiplier)*f(light.radius))*maximum):20;
 return{distance,priority:f(f(f((priority+1)|0)*distance)/f(f((light.dynamic|0)+4)*f(energy+1)))};
}

// Render adapter for the native view-volume and bounded active-light rules.
// All source lights/IDs/properties stay alive. Layers gate renderer admission;
// visibility is not reused as storage, and source animation can keep running.
// Full native fade lists, static bins and per-object lighting are separate owners.
export class RendererLightSelection{
 constructor({report=()=>{},maxLights=128}={}){this.report=report;this.maxLights=maxLights;this.managed=new Map();this.frustum=new Frustum();this.matrix=new Matrix4();this.position=new Vector3();this.reported=new Set();}
 update(scene,camera,{focus=null,objects=null,worldMatricesReady=false}={}){
  for(const [light,state]of this.managed)if(light.layers.mask===state.applied)light.layers.mask=state.original;else state.original=light.layers.mask;
  if(!worldMatricesReady){camera.updateWorldMatrix(true,false);scene.updateMatrixWorld();}this.frustum.setFromProjectionMatrix(this.matrix.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse));
  const cameraPosition=new Vector3().setFromMatrixPosition(camera.matrixWorld),target=focus??cameraPosition.toArray(),candidates=[],seen=new Set();let total=0,outside=0,disabled=0;
  const visit=callback=>objects?objects.forEach(callback):scene.traverseVisible(callback);
  visit(light=>{
   const p=light.userData.mdlLight;if(!light.isPointLight||!p||!light.layers.test(camera.layers))return;total++;seen.add(light);
   let state=this.managed.get(light);if(!state)this.managed.set(light,state={original:light.layers.mask,applied:light.layers.mask});
   if(worldMatricesReady)this.position.setFromMatrixPosition(light.matrixWorld);else light.getWorldPosition(this.position);const record={position:this.position.toArray(),color:p.color??[1,1,1],radius:Number(p.radius??0),multiplier:Number(p.multiplier??1),priority:Number(p.lightpriority??0),priorityOverride:light.userData.mdlLightPriority90??0,dynamic:Number(p.isdynamic??0),fading:Number(p.fadinglight??0)};
   const radius=nativeLightRadius(record);let admitted=radius>0&&record.multiplier>0&&record.color.some(v=>v!==0);
   if(!admitted)disabled++;
   else if(radius<1000&&this.frustum.planes.some(plane=>plane.distanceToPoint(this.position)<-radius)){admitted=false;outside++;}
   if(admitted)candidates.push({light,state,...nativeLightPriority(record,target),order:candidates.length});
   else{light.layers.mask=0;state.applied=0;}
  });
  // Native ControlLightsFade/GetNearestLights bound their active arrays at128.
  // Stable traversal order resolves equal scores; exact native std::sort tie
  // permutation and fade history are not asserted by this renderer adapter.
  candidates.sort((a,b)=>a.priority-b.priority||a.order-b.order);const limit=Math.max(0,Math.min(128,this.maxLights));
  for(const [index,c]of candidates.entries()){c.light.layers.mask=index<limit?c.state.original:0;c.state.applied=c.light.layers.mask;}
  for(const [light,state]of this.managed)if(!seen.has(light)){if(light.layers.mask===state.applied)light.layers.mask=state.original;this.managed.delete(light);}
  this.state={total,eligible:candidates.length,admitted:Math.min(candidates.length,limit),outside,disabled,limited:Math.max(0,candidates.length-limit),maxLights:limit};
  if(this.state.limited){const key=JSON.stringify(this.state);if(!this.reported.has(key)){this.reported.add(key);this.report('renderer.light-selection-partial','Native view/radius/priority admission is active; native fade history, static bins and per-object light paths remain incomplete',this.state);}}
  return this.state;
 }
 dispose(){for(const [light,state]of this.managed)if(light.layers.mask===state.applied)light.layers.mask=state.original;this.managed.clear();}
}
