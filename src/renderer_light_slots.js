import {Group,PointLight,SpotLight,DirectionalLight,HemisphereLight,DataTexture,VSMShadowMap} from 'three';
const kinds=[['point','isPointLight',PointLight,4],['spot','isSpotLight',SpotLight,7],['directional','isDirectionalLight',DirectionalLight,2],['hemisphere','isHemisphereLight',HemisphereLight,3]];
// Conservative vec4 slots per declared light field in Three lights_pars_begin.
// Fragment shadow records/samplers are separate; vertex matrices do not consume
// fragment uniform vectors. This is renderer budgeting, not native light selection.
const shadowCost={isPointLight:8,isSpotLight:6,isDirectionalLight:6};

// Three specializes EVERY lit material for scene-wide light counts. A transient
// light otherwise recompiles the entire area's shaders during gameplay. Zero
// intensity renderer-only slots keep those counts stable within a reserved
// capacity. All actual lights, priorities and shadows remain untouched. This is
// shader cache management, not native light selection or a game object registry.
export class RendererLightSlots{
 constructor(renderer,report){this.renderer=renderer;this.report=report;this.group=new Group();this.group.name='Renderer light capacity';this.slots=new Map(kinds.map(([kind])=>[kind,[]]));this.capacities=new Map();this.pointShadowCapacity=0;this.neutralShadow=new DataTexture(new Uint8Array([255,255,255,255]),1,1);this.neutralShadow.needsUpdate=true;}
 update(scene,camera=null,{shadowBudget=null,lightSelection=null,objects=null}={}){
  if(this.group.parent!==scene){this.group.removeFromParent();scene.add(this.group);}
  const counts=Object.fromEntries(kinds.map(([kind])=>[kind,0]));let shadowVectors=0,otherVectors=0,pointShadows=0,otherShadows=0,potentialPointShadows=0;const visit=callback=>objects?objects.forEach(callback):scene.traverseVisible(callback);visit(light=>{if(light.userData.rendererLightSlot)return;const p=light.userData.mdlLight;if(light.isPointLight&&p&&p.radius>0&&p.multiplier>0&&p.color?.some(v=>v!==0)&&light.userData.mdlLightShadowRequested)potentialPointShadows++;if(camera&&!light.layers.test(camera.layers))return;for(const [kind,flag]of kinds)if(light[flag])counts[kind]++;if(light.isRectAreaLight)otherVectors+=4;if(light.castShadow)for(const [flag,cost]of Object.entries(shadowCost))if(light[flag]){shadowVectors+=cost;if(light.isPointLight)pointShadows++;else otherShadows++;}});
  const limits=this.renderer.capabilities.maxFragmentUniforms??256,actualVectors=kinds.reduce((n,[kind,,,cost])=>n+counts[kind]*cost,0);
  // A camera turn can admit a different number of shadows as well as lights.
  // Reserve point-shadow uniforms/samplers upfront; neutral slots use a shared
  // white map, zero intensity and NO shadow draws. Count every padded shadow
  // plus its light against the GPU budget, without displacing a real light.
  let shadowPadding=0;
  if(shadowBudget&&this.renderer.shadowMap?.type!==VSMShadowMap&&(pointShadows||potentialPointShadows||this.pointShadowCapacity)){
   const textureLimit=Math.max(0,Math.min(shadowBudget.maxTextures-shadowBudget.reserved-otherShadows,shadowBudget.pointCapacity??Infinity)),room=limits-128-shadowVectors-otherVectors-actualVectors;
   shadowPadding=Math.max(0,Math.min(textureLimit-pointShadows,Math.floor(room/12)));
  }
  this.pointShadowCapacity=pointShadows+shadowPadding;shadowVectors+=shadowPadding*8;
  const reserved=128+shadowVectors+otherVectors;let reserve=limits-reserved-actualVectors;const state={};
  for(const [kind,,Type,cost]of kinds){const count=counts[kind],old=this.capacities.get(kind)??0;
   // The area already knows the active native lights outside this view. Size
   // the pool from that data during entry, rather than growing it on rotation.
   const potential=kind==='point'&&lightSelection?Math.max(count,count-lightSelection.admitted+Math.min(lightSelection.maxLights,lightSelection.total-lightSelection.disabled)):count;
   // Selection already reserves every potentially admitted area light. Adding
   // another 50% and rounding up made a 128-light area compile 193 slots on
   // this GPU. Reserve the next power of two of the known pool instead.
   const headroom=kind==='point'&&lightSelection?1:1.5;
   const required=count+(kind==='point'?shadowPadding:0),wanted=Math.max(old,required,potential>old?2**Math.ceil(Math.log2(Math.max(2,potential*headroom))):old);
   const extra=Math.max(0,Math.min(wanted-count,Math.floor(reserve/cost)));reserve-=extra*cost;const capacity=count+extra,slots=this.slots.get(kind);
   while(slots.length>extra){const light=slots.pop();light.removeFromParent();light.dispose?.();}
   while(slots.length<extra){const light=new Type(0x000000);light.intensity=0;light.castShadow=false;light.userData.rendererLightSlot=true;this.group.add(light);slots.push(light);}
   if(kind==='point')for(const [index,light]of slots.entries()){
    light.castShadow=index<shadowPadding;
    if(light.castShadow){light.position.set(1e6,1e6,1e6);light.shadow.autoUpdate=false;light.shadow.needsUpdate=false;light.shadow.intensity=0;light.shadow.mapSize.set(1,1);light.shadow.matrix.makeTranslation(-1e6,-1e6,-1e6);light.shadow.camera.far=1e7;light.shadow.map??={texture:this.neutralShadow,dispose(){}};}
   }
   if(capacity!==old){this.capacities.set(kind,capacity);this.report('renderer.light-capacity-changed','Renderer light uniform capacity changed; neutral slots avoid shader recompilation for transient lights within this capacity',{kind,actual:count,capacity,maxFragmentUniforms:limits,reservedFragmentVectors:reserved,lightFragmentVectors:cost});}
   state[kind]={actual:count,capacity,padding:slots.length};
   if(kind==='point'&&shadowBudget)Object.assign(state[kind],{shadowActual:pointShadows,shadowCapacity:this.pointShadowCapacity,shadowPadding});
  }
  return this.state=state;
 }
 reset(){for(const slots of this.slots.values()){for(const light of slots){light.removeFromParent();light.dispose?.();}slots.length=0;}this.capacities.clear();this.pointShadowCapacity=0;this.state=null;}
 dispose(){this.reset();this.group.removeFromParent();this.slots.clear();this.neutralShadow.dispose();}
}

// Animated model properties restore requested shadows each frame. Admission
// must therefore precede uniform padding on every entry and frame path.
export function prepareRendererLights(scene,camera,{shadowBudget,lightSlots,lightSelection,focus,delta=0,clock=null,lightOnlyMembership=false,onMembership=null}){
 const began=clock?.();
 // Animation, particles and camera presentation have finished before this
 // frame boundary. Both light admission and drawing consume this same pose.
 scene.updateMatrixWorld();
 // Camera may live outside the scene or under its own moving parent. Resolve
 // that chain once; admission can read these current matrices directly.
 camera.updateWorldMatrix(true,false);
 const matricesEnded=clock?.();
 // Rebuild each frame, so parent visibility and new/removed objects are live.
 // Admission changes layers/castShadow, not visibility; all three stages can
 // share membership while observing those preceding stages' current values.
 let hasLOD=false,slotGroupVisited=false;const objects=[],lights=lightOnlyMembership?[]:null,membership=onMembership?[]:null;scene.traverseVisible(object=>{if(onMembership&&object.isLOD)hasLOD=true;const member=object.isLight||object.material;if(member){objects.push(object);if(lights&&(object.isLight||object.isPointLight||object.isSpotLight||object.isDirectionalLight||object.isHemisphereLight||object.isRectAreaLight))lights.push(object);}if(membership){if(object===lightSlots.group){membership.push(object);slotGroupVisited=true;}else if(member&&!(object.parent===lightSlots.group&&object.userData.rendererLightSlot))membership.push(object);}});
 const membershipEnded=clock?.();
 // The sampler guard still consumes every material. Light admission and slot
 // budgeting have no mesh consumers; filtering their input avoids rebuilding
 // light-field tables for thousands of shadow-casting meshes. Opt-in until
 // paired room/GPU validation. Keep type-flagged custom lights in the list.
 const lightObjects=lights??objects;
 const selection=lightSelection?.update(scene,camera,{focus,objects:lightObjects,worldMatricesReady:true}),selectionEnded=clock?.();
 const shadows=shadowBudget.update(scene,camera,{focus,delta,objects,worldMatricesReady:true}),budgetEnded=clock?.();
 const slots=lightSlots.update(scene,camera,{shadowBudget:shadows,lightSelection:selection,objects:lightObjects});
 // Slot creation/positioning happens after the scene pass. Update only this
 // renderer-owned subtree; real meshes/lights have not moved in these stages.
 lightSlots.group.updateWorldMatrix(true,true);
 const slotsEnded=clock?.();
 // Optional same-pass handoff only. Do not retain the list in serializable
 // diagnostics or reuse it across frames. Source poses and visibility are live.
 // The slot owner can replace/add neutral lights after the initial visit.
 // Retain its live group at the original traversal position, not stale lights.
 if(membership&&!slotGroupVisited&&lightSlots.group.parent===scene&&scene.visible&&lightSlots.group.visible)membership.push(lightSlots.group);
 onMembership?.(membership,{scene,camera,hasLOD,lightSlotGroup:lightSlots.group});
 return{selection,shadows,slots,worldMatricesReady:true,timings:clock?{matricesMs:matricesEnded-began,membershipMs:membershipEnded-matricesEnded,selectionMs:selectionEnded-membershipEnded,shadowBudgetMs:budgetEnded-selectionEnded,lightSlotsMs:slotsEnded-budgetEnded}:undefined};
}

export function renderPreparedScene(renderer,scene,camera,preparation,mainBatches=null,lightUniforms=null,materialReuse=null){
 const auto=scene.matrixWorldAutoUpdate;
 if(preparation?.worldMatricesReady)scene.matrixWorldAutoUpdate=false;
 const draw=()=>mainBatches?mainBatches.render(scene,camera):renderer.render(scene,camera);
 const submit=()=>materialReuse?materialReuse.render(scene,camera,draw):draw();
 try{return lightUniforms?lightUniforms.render(scene,camera,submit):submit();}finally{scene.matrixWorldAutoUpdate=auto;}
}
