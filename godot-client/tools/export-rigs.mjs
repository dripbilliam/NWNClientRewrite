import * as T from 'three';
import {nativeAnimationName} from '../../src/native_animation.js';
import {networkAnimationContext} from '../../src/network_scene.js';
import {clientAnimationCategory} from '../../src/client_body_transition.js';
import {modelParentIndices} from '../../src/model_hierarchy.js';
import {exportNativeAnimation} from './export-native-animation.mjs';

const basis=new T.Quaternion().setFromAxisAngle(new T.Vector3(1,0,0),-Math.PI/2),inverse=basis.clone().invert();
const pose=o=>({position:o.position.toArray(),quaternion:o.quaternion.toArray(),scale:o.scale.toArray()});
function values(property,value){
 if(property==='position')return[value[0],value[2],-value[1]];
 if(property==='orientation')return basis.clone().multiply(new T.Quaternion(...value)).multiply(inverse).toArray();
 return[value[0],value[0],value[0]];
}
export function transferTrack(track){
 if(!['position','orientation','scale'].includes(track.property))return null;
 const frames=track.frames;if(!frames.length)return null;
 return{property:track.property==='orientation'?'quaternion':track.property,keys:frames.map(frame=>({time:frame.time,value:values(track.property,frame.value),...(track.interpolation==='bezier'?{in:values(track.property,frame.in),out:values(track.property,frame.out)}:{})})),sourceInterpolation:track.interpolation};
}

// Retain physical scene identity, including separate body/robe/held model roots.
// Mesh bytes remain in the existing external GLB. Only skin base arrays and
// original animation/controller records supplement that bundle.
export function prepareRigTransfer(presentation,objectIds=null){
 const rows=[...presentation.objects].map(([id,binding])=>({id,binding,object:presentation.world.registry.get(id),selected:!objectIds||objectIds.has(id)}));
 return prepareRigRows(rows,presentation.tables);
}

// Render-only effects have an isolated model graph, not a replicated creature.
// Handle 0 is local to this resource; it never enters a gameplay registry.
export function prepareVisualRigTransfer({scene,models,attachments=[]}){
 if(!scene?.isScene||models.length===0)throw Error('Visual resource needs an isolated scene and model');
 const roots=new Set(models.map(model=>model.root));
 if(roots.size!==models.length||scene.children.some(root=>!roots.has(root))||models.some(model=>model.root.parent!==scene))throw Error('Visual resource must contain exactly its owned model roots');
 return prepareRigRows([{id:0,binding:{wrapper:scene,models,visualAttachments:attachments},object:null,selected:true,renderOnly:true}],{});
}

// A creator body owns its parts through their physical bone parents. This is
// intentionally separate from the sibling-root reference/VFX attachment rule.
export function prepareCreationRigTransfer({scene,models}){
 if(!scene?.isScene||!models?.length||scene.children.length!==1||scene.children[0]!==models[0].root)throw Error('Creation preview needs exactly its owned body hierarchy');
 scene.updateMatrixWorld(true);if(scene.matrixWorld.elements.some((v,i)=>Math.abs(v-([0,5,10,15].includes(i)?1:0))>1e-12))throw Error('Creation preview scene must have an identity world transform');
 const roots=new Set(models.map(m=>m.root));if(roots.size!==models.length)throw Error('Creation preview has repeated model owners');
 for(const model of models){let p=model.root;while(p&&p!==scene)p=p.parent;if(p!==scene)throw Error('Creation part is outside its owned hierarchy');}
 scene.traverse(node=>{if(node.userData.networkObjectId!==undefined||node.userData.worldObjectId!==undefined||node.userData.mdlRoot&&!roots.has(node))throw Error('Creation preview contains an unrelated gameplay/model owner');});
 const transfer=prepareRigRows([{id:0,binding:{wrapper:scene,models},object:null,selected:true,renderOnly:true}],{}),selected=new Map();
 for(const model of transfer.data.entities[0].models){if(!selected.has(model.asset))selected.set(model.asset,new Set());if(model.clip)selected.get(model.asset).add(String(model.clip).toLowerCase());}
 for(const[index,asset]of transfer.data.assets.entries()){asset.clips=asset.clips.filter(c=>selected.get(index)?.has(String(c.name).toLowerCase()));delete asset.nativeAnimation;}
 transfer.data.counts.clips=transfer.data.assets.reduce((n,a)=>n+a.clips.length,0);transfer.data.counts.tracks=transfer.data.assets.reduce((n,a)=>n+a.clips.reduce((v,c)=>v+c.tracks.length,0),0);
 return transfer;
}

function prepareRigRows(rows,tables){
 const assets=[],assetIds=new Map(),entities=[],bindings=new WeakMap(),nodeBindings=new WeakMap();
 const counts={entities:0,nodes:0,models:0,animatedModels:0,skinMeshes:0,rigidMeshes:0,clips:0,tracks:0,attachments:0,detachedModels:0};
 function rest(instance,physical){return instance.model.nodes.map((node,i)=>{
  const object=physical.get(i),saved=instance.animator?.bindings.get(node.name.toLowerCase());
  if(!object)throw Error('Physical model node is missing: '+instance.model.modelName+' / '+i);
  return saved&&saved.object===object?{position:saved.position.toArray(),quaternion:saved.quaternion.toArray(),scale:saved.scale.toArray()}:pose(object);
 });}
 function asset(instance,physical,renderOnly){
  const source=instance.model,animator=instance.animator;if(!source)return null;
  if(assetIds.has(source))return assetIds.get(source);
  const index=assets.length;assetIds.set(source,index);
  const defaults=rest(instance,physical);
  const unsupported=new Set(),clips=(source.animations??[]).map(clip=>{
   const tracks=[];
   for(const track of clip.tracks){
    const binding=animator?.bindings.get(track.node.toLowerCase());if(!binding){unsupported.add('Missing channel binding: '+track.node);continue;}
    const part=binding.object.userData.mdlNodeIndex,converted=transferTrack(track);
    if(converted)tracks.push({part,...converted});else unsupported.add(track.property);
   }
   counts.clips++;counts.tracks+=tracks.length;
   return{name:clip.name,length:clip.length,transition:clip.transition??0,tracks,events:clip.events??[]};
  });
  assets.push({name:source.modelName,defaults,clips,unsupported:[...unsupported],...(renderOnly?{nativeAnimation:exportNativeAnimation(source)}:{})});return index;
 }
 for(const {id,binding,object,selected,renderOnly=false} of rows){
  if(!renderOnly&&![5,10].includes(object?.objectType))continue;
  const nodes=[],indices=new Map(),models=[],row={id,nodes,models,attachments:[],clipMap:{},sideMaps:{},loopMap:{},animationSource:-1,model18:Boolean(binding.model18),model18Unavailable:Boolean(binding.model18Unavailable)};
  function walk(parent,parentIndex){for(const child of parent.children){
   if(child.isMesh||child.isLight||child.isLine||child.isSprite||child.isPoints)continue;
   const index=nodes.length;indices.set(child,index);nodes.push(selected?{parent:parentIndex,...pose(child),name:child.name,visible:child.visible}:null);walk(child,index);
  }}
  walk(binding.wrapper,-1);
  for(const attachment of binding.visualAttachments??[]){
   if(!indices.has(attachment.root)||!indices.has(attachment.anchor)||![0,3].includes(attachment.flags))throw Error('Visual resource attachment is outside its owned graph');
   row.attachments.push({node:indices.get(attachment.root),anchor:indices.get(attachment.anchor),scale:attachment.root.scale.toArray(),flags:attachment.flags});counts.attachments++;
  }
  // Native held/helmet services keep these roots beside the creature and
  // copy anchor P/Q only. Ordinary parenting would incorrectly inherit scale.
  for(const held of [...binding.held??[],...binding.worn??[]]){
   if(!selected){const index=nodes.length;indices.set(held.root,index);nodes.push(null);walk(held.root,index);continue;}
   let anchor=null;const main=binding.models[0];main.root.traverse(node=>{if(!anchor&&node.userData.mdlModel===main.model.modelName&&node.userData.mdlNode?.toLowerCase()===held.anchor.toLowerCase())anchor=node;});
   if(!anchor||!indices.has(anchor))throw Error('A native held/worn anchor is missing');
   held.root.updateWorldMatrix(true,true);binding.wrapper.updateWorldMatrix(true,false);
   const matrix=binding.wrapper.matrixWorld.clone().invert().multiply(held.root.matrixWorld),p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();matrix.decompose(p,q,s);
   const index=nodes.length;indices.set(held.root,index);nodes.push({parent:-1,position:p.toArray(),quaternion:q.toArray(),scale:s.toArray(),name:held.root.name,visible:held.root.visible});walk(held.root,index);
   row.attachments.push({node:index,anchor:indices.get(anchor),scale:held.root.scale.toArray()});counts.attachments++;
  }
  // Delta assets stay sparse, but a beam can reference a different creature's
  // animated node. Index that physical hierarchy without exporting its clips,
  // defaults or skin arrays again. Node numbering uses the same walk above.
  if(!selected){
   let modelIndex=0;
   for(const instance of binding.models){if(!instance.model||!indices.has(instance.root))continue;
    const physical=[];instance.root.traverse(object=>{if(object.userData.mdlModel===instance.model.modelName&&Number.isInteger(object.userData.mdlNodeIndex))physical.push(object);});
    for(const object of [instance.root,...physical])if(indices.has(object))nodeBindings.set(object,{objectId:id,rigNode:indices.get(object),modelIndex});modelIndex++;
   }
   continue;
  }
  const ownSkin=new WeakMap();
  for(const instance of binding.models){
   if(!instance.model)continue;
   if(!indices.has(instance.root)){
    let attached=false;for(let parent=instance.root;parent;parent=parent.parent)if(parent.isScene)attached=true;
    if(attached)throw Error('A rendered model root is outside the transferred entity: '+instance.model.modelName);
    counts.detachedModels++;continue;
   }
   const physical=new Map();instance.root.traverse(o=>{if(o.userData.mdlModel===instance.model.modelName&&Number.isInteger(o.userData.mdlNodeIndex))physical.set(o.userData.mdlNodeIndex,o);});
   const modelIndex=models.length,assetIndex=asset(instance,physical,renderOnly),animator=instance.animator;
   for(const object of [instance.root,...physical.values()])if(indices.has(object))nodeBindings.set(object,{objectId:id,rigNode:indices.get(object),modelIndex});
   const partNodes=instance.model.nodes.map((_,i)=>indices.get(physical.get(i))??-1);
   if(partNodes.some(i=>i<0))throw Error('A physical model Part is outside the transferred entity');
   let visualParts={};
   if(renderOnly){const roots=modelParentIndices(instance.model).flatMap((parent,index)=>parent===-1?[index]:[]);if(roots.length!==1)throw Error('Visual model requires a single physical root');visualParts={root:indices.get(instance.root),rootPart:roots[0],partNames:instance.model.nodes.map(node=>node.name)};}
   models.push({asset:assetIndex,parts:partNodes,defaults:rest(instance,physical),follow:animator===binding.animator||(binding.animationFollowers??[]).includes(animator),clip:animator?.clip?.name??null,time:animator?.time??0,loop:animator?.loop??true,speed:animator?.nativeVisualSpeed??1,playing:Boolean(animator?.playing),...visualParts});
   if(animator===binding.animator)row.animationSource=modelIndex;
   if(animator?.model.animations.length)counts.animatedModels++;
   instance.root.traverse(mesh=>{
    if(!mesh.isMesh||!mesh.userData.sourceVertexIndices)return;
    const sourceNode=instance.model.nodes[mesh.parent?.userData.mdlNodeIndex];if(!sourceNode?.skinned)return;
    const skin=sourceNode.skinData;if(!skin?.qboneRefInv||!skin.tboneRefInv)throw Error('Native skin inverse reference arrays are unavailable');
    const sources=mesh.userData.sourceVertexIndices,position=[],weights=[],bones=[];
    for(const source of sources){const v=sourceNode.verts[source];position.push(v[0],v[2],-v[1]);weights.push(...skin.weights[source]);bones.push(...skin.boneIndices[source]);}
    const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(position,3));g.computeVertexNormals();
    ownSkin.set(mesh,{model:modelIndex,part:mesh.parent.userData.mdlNodeIndex,position,normal:Array.from(g.attributes.normal.array),uv:Array.from(mesh.geometry.attributes.uv?.array??[]),weights,bones,slots:skin.boneConstantSlots.slice(0,64),inversePositions:skin.tboneRefInv,inverseQuaternions:skin.qboneRefInv,groups:mesh.geometry.groups.map(v=>({...v}))});g.dispose();
   });
  }
  if(object?.objectType===5){const context=networkAnimationContext(object,tables,binding.bodyType);row.context={...context};row.bodyType=binding.bodyType;for(let side=0;side<=2;side++){const map=row.sideMaps[side]={};for(let code=0;code<512;code++){try{const name=nativeAnimationName(code,{...context,fieldE0:side});if(name){map[code]=name;if(side===0){row.clipMap[code]=name;row.loopMap[code]=![5,6,7,8,9].includes(code)&&(clientAnimationCategory(5,code)===1||[2,3,4].includes(code));}}}catch{/* Native mapping has a bounded dispatch table. */}}}}
  for(const parent of indices.keys())for(const mesh of parent.children){if(!mesh.isMesh)continue;const node=indices.get(parent),skin=ownSkin.get(mesh)??null;bindings.set(mesh,{rigNode:node,rigLocal:pose(mesh),...(renderOnly?{objectId:0}:{}),...(skin?{skin}: {})});if(skin)counts.skinMeshes++;else counts.rigidMeshes++;}
  entities.push(row);counts.entities++;counts.nodes+=nodes.length;counts.models+=models.length;
 }
 return{data:{version:1,assets,entities,counts},binding:mesh=>bindings.get(mesh)??null,nodeBinding:object=>nodeBindings.get(object)??null};
}
