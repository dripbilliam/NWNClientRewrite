import {Group,PointLight,SpotLight,DirectionalLight,HemisphereLight} from 'three';
const kinds=[['point','isPointLight',PointLight],['spot','isSpotLight',SpotLight],['directional','isDirectionalLight',DirectionalLight],['hemisphere','isHemisphereLight',HemisphereLight]];

// Three specializes EVERY lit material for scene-wide light counts. A transient
// light otherwise recompiles the entire area's shaders during gameplay. Zero
// intensity renderer-only slots keep those counts stable within a reserved
// capacity. All actual lights, priorities and shadows remain untouched. This is
// shader cache management, not native light selection or a game object registry.
export class RendererLightSlots{
 constructor(renderer,report){this.renderer=renderer;this.report=report;this.group=new Group();this.group.name='Renderer light capacity';this.slots=new Map(kinds.map(([kind])=>[kind,[]]));this.capacities=new Map();}
 update(scene){
  if(this.group.parent!==scene){this.group.removeFromParent();scene.add(this.group);}
  const counts=Object.fromEntries(kinds.map(([kind])=>[kind,0]));scene.traverseVisible(light=>{if(light.userData.rendererLightSlot)return;for(const [kind,flag]of kinds)if(light[flag])counts[kind]++;});
  const limits=this.renderer.capabilities.maxFragmentUniforms??256,maxSlots=Math.max(0,Math.floor((limits-128)/8));let reserve=maxSlots-Object.values(counts).reduce((a,b)=>a+b,0);const state={};
  for(const [kind,,Type]of kinds){const count=counts[kind],old=this.capacities.get(kind)??0,wanted=count>old?2**Math.ceil(Math.log2(Math.max(2,count*1.5))):old;
   const extra=Math.max(0,Math.min(wanted-count,reserve));reserve-=extra;const capacity=count+extra,slots=this.slots.get(kind);
   while(slots.length>extra){const light=slots.pop();light.removeFromParent();light.dispose?.();}
   while(slots.length<extra){const light=new Type(0x000000);light.intensity=0;light.castShadow=false;light.userData.rendererLightSlot=true;this.group.add(light);slots.push(light);}
   if(capacity!==old){this.capacities.set(kind,capacity);this.report('renderer.light-capacity-changed','Renderer light uniform capacity changed; neutral slots avoid shader recompilation for transient lights within this capacity',{kind,actual:count,capacity,maxFragmentUniforms:limits});}
   state[kind]={actual:count,capacity,padding:slots.length};
  }
  return this.state=state;
 }
 dispose(){for(const slots of this.slots.values())for(const light of slots){light.removeFromParent();light.dispose?.();}this.group.removeFromParent();this.slots.clear();this.capacities.clear();}
}
