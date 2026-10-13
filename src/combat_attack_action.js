import { OBJECT_INVALID } from './game_object_array.js';
import { actionParameter } from './object_actions.js';

// AIActionAttackObject 1403dcd50, controlling full assembly through
// 1403de2e8. Eligibility and approach are separate native operations. This
// owner preserves result1 (pending), result2 (replacement approach actions),
// and result3 (finished). No geometry or automatic-target success is inferred.
export async function executeAttackAction(actor,node,providers={}){
  if(node.actionId!==12||node.parameterTypes[0]!==3)throw new Error('Native executing attack object parameter is unavailable');
  if(typeof providers.evaluate!=='function')throw new Error('Native attack eligibility is unavailable');
  let targetId=actionParameter(node,0);
  const eligibility=await providers.evaluate(actor,targetId);
  const requireProvider=name=>{
    if(typeof providers[name]!=='function')throw new Error(`Native attack owner provider ${name} is unavailable`);
    return providers[name];
  };
  const change=async id=>{
    await requireProvider('changeTarget')(actor,node,id);
    return id===OBJECT_INVALID?3:1;
  };
  if(eligibility.decision==='clearTarget')return change(OBJECT_INVALID);
  if(eligibility.decision==='clearAnimation'){
    await requireProvider('setAnimation')(actor,0);return 3;
  }
  if(eligibility.decision==='approach')return requireProvider('approach')(actor,node,eligibility);
  if(eligibility.decision!=='round'||typeof eligibility.targetValid!=='boolean')throw new Error('Native attack owner eligibility decision is unavailable');
  const round=actor.combatRound;
  if(!round)return change(OBJECT_INVALID);
  // The stored point is reset even while paused. Round startup precedes the
  // invalid-target dispatch/replacement branch in the original implementation.
  actor.attackTargetPosition=[0,0,0];
  if(Number(round.started)===0)await requireProvider('startRound')(actor,targetId);
  await requireProvider('dispatch')(actor,targetId,eligibility.targetValid,node);
  // A paused round returns1 without searching for a replacement, including
  // a now-invalid target. After an unpaused dispatch it searches even when
  // a cancelled round action was consumed, not merely when no action was due.
  if(Number(round.paused)!==0||eligibility.targetValid)return 1;
  const replacement=await requireProvider('newTarget')(actor,targetId);
  targetId=replacement?.id??OBJECT_INVALID;
  if(!Number.isInteger(targetId))throw new Error('Native replacement combat target ID is unavailable');
  if(replacement)actor.attackTargetChanged=1;
  return change(targetId>>>0);
}
