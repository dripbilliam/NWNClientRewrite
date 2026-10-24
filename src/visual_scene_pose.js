import * as THREE from 'three';
import {commitLocalMatrix} from './managed_local_matrix.js';
import {getVisualLocalNodePose,setVisualLocalNodePose,getVisualNodePose,setVisualNodePose} from './visual_node_pose.js';
import {updateVisualNoOrientation} from './visual_orientation.js';
const f=Math.fround,BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert();

// Gob::GetPart14008f420 treats case-insensitive "root" as its physical root
// part, independent of the model's authored root name. Other scene/model
// hierarchy and floating-point behavior remain an adapter, not a native graph.
function part(model,name){
 const key=String(name).toLowerCase(),roots=model.root.children.filter(node=>node.userData.mdlNode);
 if(roots.length!==1)throw new Error('Visual main model requires a single physical root part');
 if(key==='root')return roots[0];
 let found=null;model.root.traverse(node=>{if(!found&&node.userData.mdlModel===model.root.userData.mdlRoot&&node.userData.mdlNode?.toLowerCase()===key)found=node;});return found;
}
function localState(node){
 const q=INVERSE.clone().multiply(node.quaternion).multiply(BASIS);
 return{position10:[node.position.x,-node.position.z,node.position.y].map(f),quaternion1c:[q.w,q.x,q.y,q.z].map(f),dirty60:0};
}
export function visualMainModel(render){
 let root=render.userData.mdlRoot?render:render.children.find(node=>node.userData.mdlRoot);
 if(!root)render.traverse(node=>{if(!root&&node.userData.mdlRoot)root=node;});
 if(!root)return null;return{root,animator:null};
}
function writeLocal(model,node,state){
 node.position.set(state.position10[0],state.position10[2],-state.position10[1]);
 const [w,x,y,z]=state.quaternion1c;node.quaternion.copy(BASIS).multiply(new THREE.Quaternion(x,y,z,w)).multiply(INVERSE);
 commitLocalMatrix(node);
 const binding=model.animator?.bindings.get(node.userData.mdlNode.toLowerCase());
 if(binding){binding.position.copy(node.position);binding.quaternion.copy(node.quaternion);}
 node.userData.mdlControlGate60=state.dirty60;
 model.animator?.nativePose?.setManualPose(node,state.position10,state.quaternion1c);
 model.root.updateWorldMatrix(true,true);
}
function globalPose(node){
 node.updateWorldMatrix(true,false);const position=node.getWorldPosition(new THREE.Vector3()),q=INVERSE.clone().multiply(node.getWorldQuaternion(new THREE.Quaternion())).multiply(BASIS);
 return{position:[position.x,-position.z,position.y].map(f),quaternion:[q.w,q.x,q.y,q.z].map(f)};
}
// Optional sceneRoot adapter represents Gob object P/Q independently of the
// anchor's scale. Native AttachToObject copies only anchor P/Q (+a8/+b4),
// not its scale. SceneRoot must have an identity world transform.
export function visualLocalPoseServices({sceneRoot}={}){
 const attachments=new Map(),assertScene=()=>{sceneRoot.updateWorldMatrix(true,false);const identity=new THREE.Matrix4().elements;if(sceneRoot.matrixWorld.elements.some((v,i)=>Math.abs(v-identity[i])>1e-12))throw new Error('Visual scene root requires an identity world transform');};
 const sync=entry=>{
  const baseUpdate=()=>{entry.anchor.updateWorldMatrix(true,false);entry.model.root.position.copy(entry.anchor.getWorldPosition(new THREE.Vector3()));entry.model.root.quaternion.copy(entry.anchor.getWorldQuaternion(new THREE.Quaternion()));return 1;};
  if(entry.flags===3)updateVisualNoOrientation({object18:entry.model.root},0,{orientation:o=>o.quaternion.clone(),setOrientation:(o,q)=>o.quaternion.copy(q),baseUpdate});else baseUpdate();
  entry.model.root.updateWorldMatrix(true,true);
 };
 return{
  modelHandle:render=>visualMainModel(render),
  nodePose:(model,name)=>{const position=[0,0,0],quaternion=[1,0,0,0],node=part(model,name);getVisualNodePose(model,name,position,quaternion,{findNode:()=>node,globalPose});return{position,quaternion};},
  nodePoseInto:(model,name,position,quaternion)=>getVisualNodePose(model,name,position,quaternion,{findNode:()=>part(model,name),globalPose}),
  setNodePose:(model,name,position,quaternion)=>{
   const node=part(model,name);if(!node)return 0;const state=localState(node);
   const result=setVisualNodePose(model,name,position,quaternion,{findNode:()=>state,globalPose:()=>{writeLocal(model,node,state);return globalPose(node);}});
   writeLocal(model,node,state);return result;
  },
  localNodePose:(model,name,defaults)=>{
   const node=part(model,name),position=[...defaults.position],quaternion=[...defaults.quaternion];
   getVisualLocalNodePose(model,name,position,quaternion,{findNode:()=>node?localState(node):null});return{position,quaternion};
  },
  setLocalNodePose:(model,name,position,quaternion)=>{
   const node=part(model,name);if(!node)return 0;
   const state=localState(node),result=setVisualLocalNodePose(model,name,position,quaternion,{findNode:()=>state});
   // The native setter also sets Part60. Native hierarchy control skips that
   // part while preserving child animation; it is not just a new rest pose.
   writeLocal(model,node,state);return result;
  },
  setParent:(model,parent,name,flags)=>{
   if(sceneRoot){
    if(!parent){attachments.delete(model);return null;}
    if(flags!==0&&flags!==3)throw new Error('Visual scene parent mode requires its native orientation behavior');
    assertScene();const anchor=part(parent,name);if(!anchor){attachments.delete(model);return null;}
    sceneRoot.add(model.root);model.root.position.copy(anchor.getWorldPosition(new THREE.Vector3()));model.root.quaternion.copy(anchor.getWorldQuaternion(new THREE.Quaternion()));model.root.updateWorldMatrix(true,true);
    attachments.set(model,{model,anchor,flags});return anchor;
   }
   if(flags!==0)throw new Error('Visual scene parent mode requires its native orientation behavior');
   if(!parent)throw new Error('Visual scene unparenting requires explicit scene lifetime ownership');
   const anchor=part(parent,name);if(!anchor)return null;
   anchor.add(model.root);model.root.position.set(0,0,0);model.root.quaternion.identity();model.root.updateWorldMatrix(true,true);return anchor;
  },
  forgetAttachment:model=>attachments.delete(model),
  // Read-only ownership view for native presentation transfer. Return a new
  // record so a consumer cannot change the attachment manager's flags/owner.
  attachmentFor:model=>{const entry=attachments.get(model);return entry?{anchor:entry.anchor,flags:entry.flags}:null;},
  updateAttachments:()=>{if(!sceneRoot)return;assertScene();for(const [model,entry]of attachments){if(model.root.parent!==sceneRoot){attachments.delete(model);continue;}sync(entry);}}
 };
}
