import {Vector3} from 'three';
import {RendererNativeShadows} from './renderer_native_shadows.js';
// Three allocates a fragment sampler per shadow-casting light. The original
// renderer's per-object light/cache selection is still a separate owner. This
// hardware guard retains ALL light colors/intensities and authored shadow
// requests, admitting only shadows that fit alongside material/spot maps.
export class RendererShadowBudget{
 constructor({renderer,report=()=>{},nativeSelection=false,maximum=3}){Object.assign(this,{renderer,report});this.states=new Map();this.materialFields=new WeakMap();this.reported=new Set();this.state=null;this.native=nativeSelection?new RendererNativeShadows({maximum}):null;}
 get maximum(){return this.native?.maximum??3;}
 set maximum(value){if(this.native)this.native.maximum=value;}
 restore(light,state){if(light.castShadow===state.applied)light.castShadow=state.requested;if(light.shadow&&light.shadow.intensity===state.intensityApplied)light.shadow.intensity=state.intensity;}
 reset(){for(const [light,state]of this.states)this.restore(light,state);this.states.clear();this.native?.reset();this.state=null;}
 materialTextures(material){
  // Standard materials declare their map fields even when null. Remember that
  // schema, not the texture count: replacing/clearing a map is seen immediately.
  // needsUpdate/version invalidates the schema when a material is reconfigured.
  let fields=this.materialFields.get(material);
  if(!fields||fields.version!==material.version){fields={version:material.version,keys:Object.keys(material).filter(key=>material[key]==null||material[key]?.isTexture)};this.materialFields.set(material,fields);}
  let count=0;for(const key of fields.keys)if(material[key]?.isTexture)count++;
  // Custom uniforms can change independently of material.version. Count them
  // live, including variable sampler arrays, just like the original guard.
  if(material.uniforms)for(const key in material.uniforms){const value=material.uniforms[key]?.value;if(value?.isTexture)count++;else if(Array.isArray(value))for(const entry of value)if(entry?.isTexture)count++;}
  return count;
 }
 update(scene,camera,{objects=null,worldMatricesReady=false,focus=null,delta=0}={}){
  let materialTextures=0,spotMaps=0,areaLights=false;const candidates=[],materials=new Set(),seen=new Set(),present=[],position=new Vector3(),cameraPosition=worldMatricesReady?new Vector3().setFromMatrixPosition(camera.matrixWorld):camera.getWorldPosition(new Vector3());
  // Shared materials contribute the same maximum for every mesh. Inspect once
  // in this synchronous pass; a fresh set still observes every next-frame map,
  // uniform and environment change without retaining another resource owner.
  const scan=material=>{if(materials.has(material))return;materials.add(material);const count=this.materialTextures(material)+Number(Boolean(scene.environment&&!material.envMap));materialTextures=Math.max(materialTextures,count);};
  const visit=callback=>objects?objects.forEach(callback):scene.traverseVisible(callback);
  visit(o=>{
   if(o.userData.rendererLightSlot)return;
   if(o.isLight){
    if(o.shadow){seen.add(o);if(o.userData.mdlLight)present.push(o);}
    if(!o.layers.test(camera.layers))return;
    if(o.isSpotLight&&o.map)spotMaps++;if(o.isRectAreaLight)areaLights=true;
    if(!o.shadow)return;let state=this.states.get(o);if(!state){state={requested:o.castShadow,applied:o.castShadow,intensity:o.shadow.intensity,intensityApplied:o.shadow.intensity};this.states.set(o,state);}else{if(o.castShadow!==state.applied)state.requested=o.castShadow;if(o.shadow.intensity!==state.intensityApplied)state.intensity=o.shadow.intensity;}
    const requested=o.userData.mdlLightShadowRequested??state.requested;
    if(requested){if(worldMatricesReady)position.setFromMatrixPosition(o.matrixWorld);else o.getWorldPosition(position);candidates.push({light:o,state,position:position.toArray(),distance:o.isDirectionalLight?-1:position.distanceToSquared(cameraPosition),order:candidates.length});}else{o.castShadow=false;state.applied=false;}
   }
   if(!o.material)return;
   if(Array.isArray(o.material))for(const material of o.material)scan(material);else scan(o.material);
  });
  for(const [light,state]of this.states)if(!seen.has(light)){this.restore(light,state);this.states.delete(light);}
  const maxTextures=this.renderer.capabilities.maxTextures,reserved=Math.max(1,materialTextures)+spotMaps+(areaLights?2:0),capacity=Math.max(0,maxTextures-reserved);
  const native=this.native?.update(candidates,present,{focus:focus??cameraPosition.toArray(),delta,scene});
  const admitted=candidates.filter(c=>!native||!c.light.userData.mdlLight||native.selected.has(c.light));
  admitted.sort((a,b)=>a.distance-b.distance||a.order-b.order);const selected=new Set(admitted.slice(0,capacity).map(c=>c.light));
  for(const c of candidates){c.light.castShadow=selected.has(c.light);c.state.applied=c.light.castShadow;if(native&&c.light.userData.mdlLight){c.light.shadow.intensity=c.state.intensity*(native.fades.get(c.light)??0);c.state.intensityApplied=c.light.shadow.intensity;}}
  this.state={maxTextures,reserved,requested:candidates.length,admitted:selected.size,limited:Math.max(0,admitted.length-capacity)};
  // All supported settings (1..3) share one shader profile. Lowering actual
  // shadow work must not synchronously recompile every lit material. Neutral
  // slots have zero intensity and never allocate/render a shadow atlas.
  if(native)Object.assign(this.state,{native:this.native.state,policyLimited:candidates.length-admitted.length,pointCapacity:Math.min(capacity,6+candidates.filter(c=>c.light.isPointLight&&!c.light.userData.mdlLight).length)});
  if(this.state.limited){const key=JSON.stringify(this.state);if(!this.reported.has(key)){this.reported.add(key);this.report('renderer.shadow-budget-partial','Shadow sampler hardware limit applied after light selection',this.state);}}
  return this.state;
 }
 snapshot(){return this.state;}
}
