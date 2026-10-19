import {modelParentIndices} from './model_hierarchy.js';
import * as THREE from 'three';
import {createReferenceObjects,destroyReferencePart,reattachModelReferences} from './model_references.js';
import {referenceModelName} from './model_reference_assets.js';
import {visualLocalPoseServices} from './visual_scene_pose.js';
const BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert(),f=Math.fround;
const referenceScenes=new WeakMap();
export const modelReferenceSceneForRoot=root=>referenceScenes.get(root)??null;

export function modelReferenceParts(model,root){
 const groups=new Map();root.traverse(group=>{if(group.userData.mdlModel===model.modelName&&Number.isInteger(group.userData.mdlNodeIndex))groups.set(group.userData.mdlNodeIndex,group);});
 const parents=modelParentIndices(model),parts=model.nodes.map((node,index)=>({node,group:groups.get(index),children38:[],model68:null,
  header8:{flags98:node.nativeNode?.flags98??(node.type==='reference'?0x11:1),modelA0:referenceModelName(node),reattachableE0:node.reference?.reattachable??node.properties?.reattachable}}));
 const roots=[];parts.forEach((part,i)=>{if(!part.group)throw new Error(`Reference model physical part ${i} is unavailable`);if(parents[i]===-1)roots.push(part);else parts[parents[i]].children38.push(part);});
 if(roots.length!==1)throw new Error('Reference model requires a single physical root');return roots[0];
}

// Three.js boundary around the original reference owner. Each referenced model
// is a full independent render instance, attached by P/Q (without inheriting
// the anchor's scale). Child resources carry no canonical gameplay IDs.
export class ModelReferenceScene {
 constructor({owner,asset,sceneRoot,createModel,destroyModel}){
  Object.assign(this,{owner,asset,sceneRoot,createModel,destroyModel});this.models=[];this.closed=false;
  this.parts=modelReferenceParts(asset.model,owner.root);this.poses=visualLocalPoseServices({sceneRoot});
  try{createReferenceObjects(owner,this.parts,{
   asReference:part=>part.node.type==='reference'?part:null,
   create:name=>{const childAsset=asset.references.get(name.toLowerCase());if(!childAsset)throw new Error(`Referenced model ${name} was not prefetched`);const child=createModel(childAsset,name);child.referenceParent=this;this.models.push(child);return child;},
   name:part=>part.node.name,
   attach:(child,parent,name,flags)=>{if(!this.poses.setParent(child,parent,name,flags))throw new Error(`Reference attachment part ${name} is unavailable`);},
  });referenceScenes.set(owner.root,this);}catch(error){this.dispose();throw error;}
 }
 partForGroup(group){const queue=[this.parts];while(queue.length){const part=queue.shift();if(part.group===group)return part;queue.push(...part.children38);}return null;}
 update(delta){
  if(this.closed)return;
  for(const model of this.models)model.animator.update(delta);
  this.poses.updateAttachments();
  for(const model of this.models)model.references?.update(delta);
 }
 reattach(target,name){
  if(this.closed)throw new Error('Cannot reattach a disposed reference model');
  if(this.owner.root.parent&&this.owner.root.parent!==this.sceneRoot)throw new Error('Reference Gob base transform requires the owned scene root');
  reattachModelReferences(this.owner,target,name,{root:()=>this.parts,asReference:part=>part.node.type==='reference'?part:null,name:part=>part.node.name,
   attach:(model,parent,part,flags)=>{if(!this.poses.setParent(model,parent,part,flags))throw new Error(`Reattachment part ${part} is unavailable`);},
   position:model=>[model.root.position.x,-model.root.position.z,model.root.position.y].map(f),
   orientation:model=>{const q=INVERSE.clone().multiply(model.root.quaternion).multiply(BASIS);return[q.w,q.x,q.y,q.z].map(f);},
   setOrientation:(model,q)=>{model.root.quaternion.copy(BASIS).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(INVERSE);model.root.updateWorldMatrix(true,true);},
  });
 }
 dispose(){
  if(this.closed)return;this.closed=true;referenceScenes.delete(this.owner.root);
  const visit=part=>{if(part.node.type==='reference')destroyReferencePart(part,0,{destroy:model=>{this.poses.forgetAttachment(model);this.destroyModel(model);},destroyPart:()=>{},freePart:()=>{}});for(const child of part.children38)visit(child);};
  visit(this.parts);this.models=[];
 }
}
