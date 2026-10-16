import {addObjectAction,actionParameter} from './object_actions.js';
const f=Math.fround;
const bits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getInt32(0,true);};
const parameters=(id,run,distance,flags)=>[{type:3,value:id},{type:1,value:run},{type:2,value:bits(distance)},{type:1,value:flags}];

// ExecuteCommandActionFollowObject14050dc60, VM167. The original neither
// validates the target nor checks commandability before appending55 then58.
export function scriptForceFollow(actor,targetId,distance=0,flags=0){
  if(actor?.objectType!==5)return;
  for(const id of [55,58])addObjectAction(actor.objectActionState,id,65535,parameters(targetId,1,f(distance),flags|0));
}

// AIActionForceFollowObject1403beaa0. Sample target position before the three
// front insertions. Keep repeated object casts and native ownership groups.
export async function executeForceFollow(actor,node,p){
  const id=actionParameter(node,0),run=actionParameter(node,1),distance=node.parameterCount>2?actionParameter(node,2):0,flags=node.parameterCount>3?actionParameter(node,3):0;
  const gameObject=await p.object(id);if(!gameObject||!await p.asObject(gameObject))return 3;
  const target=await p.asObject(gameObject),point=target.position.slice(),areaId=(await p.asObject(gameObject)).areaId;
  addObjectAction(actor.objectActionState,55,65535,parameters(id,run,distance,flags),true);
  addObjectAction(actor.objectActionState,30,65534,[{type:2,value:bits(1)}],true);
  addObjectAction(actor.objectActionState,17,65534,[{type:3,value:id},{type:1,value:run},{type:2,value:bits(distance)},{type:2,value:bits(distance)},{type:1,value:1}],true);
  await p.moveFront(actor,65534,point,areaId,id,run,distance,15,0,0,flags,0,0,0);return 2;
}

// AIActionCheckForceFollowObject1403b1540. Always requeues58 then55,
// including raw values of all four parameter cells, and reports completion2.
export function checkForceFollow(actor,node){
  const args=parameters(actionParameter(node,0),actionParameter(node,1),actionParameter(node,2),actionParameter(node,3));
  addObjectAction(actor.objectActionState,58,65535,args,true);addObjectAction(actor.objectActionState,55,65535,args,true);return 2;
}
