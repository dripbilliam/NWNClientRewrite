import * as THREE from 'three';
import {ModelVisualTransforms} from './model_visual_transform.js';
import {secondsToWorldDelta,addWorldTimes,subtractWorldTimes} from './world_timer.js';

function wrapModels(parent,models){
 const group=new THREE.Group();group.name='Native model visual transform';parent.add(group);
 for(const model of models)group.add(model.root);return group;
}
export function networkModelVisuals(scene,object,binding){
 const providers={clock:()=>BigInt(Math.trunc(performance.now()*1000)),worldTimer:()=>scene.combat?.timer??null,
  worldTime:timer=>timer.time(),worldSeconds:(timer,seconds)=>secondsToWorldDelta(seconds,timer.secondsPerDay).time,
  addWorld:(timer,a,b)=>addWorldTimes(a,b,timer.dayLength),subtractWorld:(timer,a,b)=>subtractWorldTimes(a,b,timer.dayLength)};
 const held=[];
 for(const h of [...binding.held??[],...binding.worn??[]]){
  const state=new ModelVisualTransforms({providers}),root=state.unit(wrapModels(h.root,h.pieces),[h.pieces[0].animator]),scopes=new Map([[255,root]]);state.root=root;
  for(const model of h.pieces.slice(1))if(model.nativeVisualScope!==undefined)scopes.set(model.nativeVisualScope,state.unit(wrapModels(model.root.parent,[model]),[model.animator]));
  state.lookup=scope=>scopes.get(scope)??null;held.push({binding:h,state});
 }
 const state=new ModelVisualTransforms({providers}),rootModels=object.objectType===6?binding.models:[binding.models[0]],root=state.unit(wrapModels(binding.wrapper,rootModels),[rootModels[0].animator]);state.root=root;
 const scopes=new Map([[255,root]]),heldModels=new Set([...binding.held??[],...binding.worn??[]].flatMap(h=>h.pieces));
 for(const model of binding.models.slice(1))if(!model.nativeItemComponent&&!heldModels.has(model)&&model.nativeVisualScope!==undefined){
  scopes.set(model.nativeVisualScope,state.unit(wrapModels(model.root.parent,[model]),[model.animator]));
 }
 state.lookup=scope=>{
  if(scope>=244&&scope<=251){const entry=held.find(h=>h.binding.kind!=='helmet'&&Boolean(h.binding.right)===(scope<248));return entry?.state.lookup(252+(scope-244)%4)??null;}
  return scopes.get(scope)??null;
 };
 return{
  root,state,
  sync(current){
   const s=current.replicated??{};state.sync(s.visualTransform??(current.objectType===6?(current.item??s.item)?.visualTransform:undefined));
   for(const h of held){const item=current.appearance?.equipment?.find(e=>e.id===h.binding.itemId)?.item;h.state.sync(item?.visualTransform);}
  },
  update(){state.update();for(const h of held){h.state.update();h.binding.root.scale.setScalar(h.binding.scale*root.scale);}},
  snapshot(){return{scopes:[...state.scopes],scale:root.scale,position:root.group.position.toArray(),held:held.map(h=>({itemId:h.binding.itemId,scale:h.state.root.scale,scopes:[...h.state.scopes]}))};},
  dispose(){state.dispose();for(const h of held)h.state.dispose();}
 };
}
