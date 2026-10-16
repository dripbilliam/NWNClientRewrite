// EffectAppear482, OnApplyAppear1404272c0 and AddAppearActions14037d090.
export function constructAppearEffect(args,self,p){return p.create(81,self,[args.length?args[0]|0:1]);}
export async function applyAppearEffect(object,effect,p){
  const animation=(effect.integers[0]|0)===2?95:63;
  if(object.objectType===5){const actor=p.asCreature(object);await p.clear(actor);await p.add(actor,animation);}
  return 1;
}
export async function addAppearActions(actor,animation,p){
  if(actor.nativeFieldEc===0)return 0;
  await p.queue(actor,52,65535,[{type:1,value:animation|0}],false);
  await p.interrupt(actor,actor.objectActionState.lastGroup,0);return 1;
}
// AIActionAppear1403ac703..1403ac7d0 (profiling disabled). Duration is
// fixed2000ms independently of clip length and incoming animation speed.
export async function executeAppearAction(actor,node,p){
  const animation=node.parameterCount?node.parameterData[0]|0:63;
  const elapsed=await p.elapsed(actor);if(!Number.isInteger(elapsed))throw new Error('Native appear elapsed time is unavailable');
  if((elapsed>>>0)<2000){actor.nativeAnimationSpeedDC=1;await p.setAnimation(actor,animation);return 1;}
  if(p.asCreature(actor)){actor.nativeAnimationSpeedDC=1;await p.setAnimation(actor,1);}
  return 2;
}
