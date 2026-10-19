import {Vector3} from 'three';
// Three allocates a fragment sampler per shadow-casting light. The original
// renderer's per-object light/cache selection is still a separate owner. This
// hardware guard retains ALL light colors/intensities and authored shadow
// requests, admitting only shadows that fit alongside material/spot maps.
export class RendererShadowBudget{
 constructor({renderer,report}){Object.assign(this,{renderer,report});this.states=new WeakMap();this.reported=new Set();this.state=null;}
 update(scene,camera){
  let materialTextures=0,spotMaps=0,areaLights=false;const candidates=[],position=new Vector3(),cameraPosition=camera.getWorldPosition(new Vector3());
  scene.traverseVisible(o=>{
   if(o.isLight){
    if(o.isSpotLight&&o.map)spotMaps++;if(o.isRectAreaLight)areaLights=true;
    if(!o.shadow)return;let state=this.states.get(o);if(!state){state={requested:o.castShadow,applied:o.castShadow};this.states.set(o,state);}else if(o.castShadow!==state.applied)state.requested=o.castShadow;
    const requested=o.userData.mdlLightShadowRequested??state.requested;
    if(requested){o.getWorldPosition(position);candidates.push({light:o,state,distance:o.isDirectionalLight?-1:position.distanceToSquared(cameraPosition),order:candidates.length});}else{o.castShadow=false;state.applied=false;}
   }
   if(!o.material)return;
   for(const material of Array.isArray(o.material)?o.material:[o.material]){
    let count=Object.values(material).filter(v=>v?.isTexture).length;
    for(const uniform of Object.values(material.uniforms??{})){const v=uniform?.value;if(v?.isTexture)count++;else if(Array.isArray(v))count+=v.filter(v=>v?.isTexture).length;}
    if(scene.environment&&!material.envMap)count++;materialTextures=Math.max(materialTextures,count);
   }
  });
  const maxTextures=this.renderer.capabilities.maxTextures,reserved=Math.max(1,materialTextures)+spotMaps+(areaLights?2:0),capacity=Math.max(0,maxTextures-reserved);
  candidates.sort((a,b)=>a.distance-b.distance||a.order-b.order);
  for(const [index,c]of candidates.entries()){c.light.castShadow=index<capacity;c.state.applied=c.light.castShadow;}
  this.state={maxTextures,reserved,requested:candidates.length,admitted:Math.min(capacity,candidates.length),limited:Math.max(0,candidates.length-capacity)};
  if(this.state.limited){const key=JSON.stringify(this.state);if(!this.reported.has(key)){this.reported.add(key);this.report('renderer.shadow-budget-partial','Shadow samplers are limited to the GPU capacity; nearest-light admission is a renderer fallback pending native per-object light selection',this.state);}}
  return this.state;
 }
 snapshot(){return this.state;}
}
