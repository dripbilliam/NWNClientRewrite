import {OBJECT_INVALID} from './game_object_array.js';
import {actionParameter} from './object_actions.js';
const f=Math.fround,bits=value=>{const data=new DataView(new ArrayBuffer(4));data.setFloat32(0,value,true);return data.getInt32(0,true);};
const radiusParameters=(id,range)=>[{type:3,value:id},{type:1,value:1},{type:2,value:bits(range)},{type:2,value:bits(range)},{type:1,value:1}];
const distanceSquared=(a,b)=>{const d=a.map((v,i)=>f(f(v)-f(b[i])));return f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]));};

// AddCounterSpellActions14037e460. A new counter order can release a
// running cast's cancellation veto before ClearAllActions visits it.
export async function addCounterspellActions(actor,id,p){
  id>>>=0;if(id===OBJECT_INVALID)return 0;
  const target=p.creature(id);if(!target||!p.area(actor)||id===actor.id||!p.area(target))return 0;
  if(!p.area(target))return 1;
  if((actor.nativeField8d4&2)===0)return 0;
  const head=p.head(actor);
  if(head&&[15,46].includes(head.actionId)&&head.nativeField9c===0)head.nativeField9c=1;
  await p.clear(actor);
  await p.queue(actor,50,65535,[{type:3,value:id}],true);
  await p.queue(actor,17,65534,radiusParameters(id,f(p.range)),true);
  actor.counterSpellTargetId=id;return 1;
}

// AIActionCounterSpell1403b6b02..1403b6f54, profiling disabled. Preserve
// the original unusual actor check: reject only dead==1 AND dying==1.
export async function executeCounterspellAction(actor,node,p){
  if(await p.dead(actor)===1&&await p.dying(actor)===1)return 3;
  await p.activityManager(actor,4);
  const id=actionParameter(node,0),target=p.creature(id);
  if(!target||await p.dead(target)!==0||await p.dying(target)!==0)return 3;
  const area=p.area(target);if(!area)return 1;
  const actorArea=p.area(actor);if(!actorArea)throw new Error('Native counterspell actor area is unavailable');
  const range=f(p.range),point=p.position(target).map(f);
  if(area.id!==actorArea.id||distanceSquared(p.position(actor),point)>f(range*range)){
    if((actor.nativeField8d4&2)===0){await p.feedback(actor,7);return 3;}
    await p.queue(actor,50,node.groupId,[{type:3,value:id}],true);
    await p.queue(actor,17,node.groupId,radiusParameters(id,range),true);
    await p.moveFront(actor,node.groupId,point,area.id,id,1,range);
    await p.waitFront(actor,node.groupId);return 2;
  }
  await p.broadcastState(actor);await p.initiative(actor);
  if((actor.combatMode&255)!==4)await p.setMode(actor,4,0);
  if(actor.counterSpellTargetId!==id)actor.counterSpellTargetId=id;
  if(p.lock(actor)!==id)await p.setLock(actor,id);
  return 1;
}

// ClearAction50 at140387293..140387428 and common tail. It does not
// clear6f4 or compact the other creature's counterspeller storage.
export async function clearCounterspellAction(actor,node,head,p){
  if(node.nativeField9c===0)return 0;
  const target=p.creature(actionParameter(node,0));
  if(target)p.remove(target,actor.id);
  await p.setAnimation(actor,1);await p.setLock(actor,OBJECT_INVALID);actor.nativeField81c=0;
  await p.setMode(actor,0,1);
  if(p.lock(actor)!==OBJECT_INVALID)await p.setLock(actor,OBJECT_INVALID);
  if(head===1)actor.objectActionState.startDay=actor.objectActionState.startTime=0;
  return 1;
}
