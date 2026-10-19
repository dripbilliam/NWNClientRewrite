import {nativeFloatEntry} from './movement_rate.js';
import {updateModelLight} from './model_light.js';

// ProcessTilePart1400cb890 captures only model-name + ml1/ml2 nodes.
// Main apply84f9a0 reads LightColor (native table-array+1b8), not TileColor.
export function tileMainLightColors(indices,table){
 if(!Array.isArray(indices)||indices.length!==2||!indices.every(Number.isInteger))throw new Error('Native tile main-light indices are unavailable');
 return indices.map(index=>['RED','GREEN','BLUE'].map(column=>nativeFloatEntry(table,index&255,column).value));
}

// Scene::SetTileLights1400d3e60 mutates resolved PartLight state only when
// RGB changes. Keep that separate from authored/cached model definitions.
export function applyTileMainLights(instance,modelName,colors,configureShadow=null){
 const prefix=modelName.split('\0')[0].slice(0,60).toLowerCase(),slots=[null,null];
 instance.root.traverse(object=>{const name=object.userData.mdlNode?.toLowerCase();const i=name===prefix+'ml1'?0:name===prefix+'ml2'?1:-1;if(i!==-1)slots[i]=object.children.find(child=>child.isLight&&child.userData.mdlLight)??null;});
 return slots.map((light,i)=>{
  if(!light)return{present:false,changed:false};
  const p=light.userData.mdlLight,color=colors[i].map(Math.fround),changed=p.color.some((value,j)=>Math.fround(value*(p.multiplier??1))!==color[j]);
  if(changed){
   // The native palette writes already-resolved RGB at PartLight+68. Its
   // authored node multiplier has already been consumed by that point.
   Object.assign(p,{color,multiplier:1,shadow:1,affectdynamic:1,radius:i===0?10:5,shadowradius:i===0?12:8});
   light.userData.mdlLightPriority90=4;
   updateModelLight(light);
   light.castShadow=!(Number(p.ambientonly)>0);light.userData.mdlLightShadowRequested=light.castShadow;if(light.castShadow)configureShadow?.(light);
   // Animation reset must retain the new instance baseline. Later animated
   // controllers can still replace these channels, as on native PartLight.
   for(const binding of instance.animator?.bindings.values()??[])for(const saved of binding.lights)if(saved.light===light)saved.properties=structuredClone(p);
  }
  return{present:true,changed,color:[...p.color],radius:p.radius,shadowRadius:p.shadowradius,shadow:p.shadow,affectDynamic:p.affectdynamic,priority:light.userData.mdlLightPriority90??p.lightpriority};
 });
}
