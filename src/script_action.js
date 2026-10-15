import {addObjectAction,actionParameter} from './object_actions.js';

// CNWSObject::AddDoCommandAction1404ab090 and AIActionDoCommand1404a0500.
// The type5 parameter owns the captured VM situation until execution/deletion.
export async function addDoCommandAction(actor,situation,deleteSituation){
  if(!Number.isInteger(actor.nativeFieldEc))throw new Error('Native commandability field is unavailable');
  if(actor.nativeFieldEc===0){await deleteSituation(situation);return 0;}
  if(!actor.objectActionState)throw new Error('Native object action state is unavailable');
  addObjectAction(actor.objectActionState,37,65535,[{type:5,value:situation}]);
  return 1;
}

export async function executeDoCommand(actor,node,{dead,dying,runSituation}){
  if(await dead(actor)===1||await dying(actor)===1)return 3;
  const situation=actionParameter(node,0);
  await runSituation(situation,actor.id);
  // RunScriptSituation owns deletion, including a script that aborts.
  node.parameterData[0]=0;
  return 2;
}
