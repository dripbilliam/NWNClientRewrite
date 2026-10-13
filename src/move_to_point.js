import { OBJECT_INVALID } from './game_object_array.js';
import { actionParameter,disposeObjectAction } from './object_actions.js';
import { addMoveToPointFront,addPathfindingWaitFront } from './movement_actions.js';
import { normalizeOrientation } from './combat_lifecycle.js';

const f=Math.fround,invalid=OBJECT_INVALID;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native move ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native move provider ${n} is unavailable`);return p[n];};
const native=value=>{if(!Array.isArray(value)||value.length!==3||!value.every(Number.isFinite))throw new Error('Native move point is unavailable');return[f(value[0]),f(-value[2]),f(value[1])];};
const render=value=>[value[0],value[2],-value[1]];
const distance=(a,b)=>{const [x,y,z]=a.map((v,i)=>f(v-b[i]));return f(f(f(x*x)+f(y*y))+f(z*z));};
const normalize=value=>{const v=normalizeOrientation(render(value));return[v[0],-v[2],v[1]];};
const write=(path,offset,point)=>point.forEach((v,i)=>path.raw.setFloat32(offset+i*4,v,true));
const read=(path,offset)=>[0,4,8].map(i=>path.raw.getFloat32(offset+i,true));

// DeleteCurrentAIAction140490ff0 is reached only for a matching head
// action2/17/18, target raw slot0, and group. Never delete unrelated actions.
export async function deleteMatchingMoveFollowup(actor,targetId,group){
  const list=actor.objectActionState.list,node=list.head?.action;
  if(node&&[2,17,18].includes(node.actionId)&&node.parameterData[0]===(targetId|0)&&node.groupId===(group&65535)){
    list.shift();await disposeObjectAction(node);
  }
}

// AIActionMoveToPoint1403c37e0..1403c5014. Parameters retain native XYZ
// float bits, client-path sequence byte, group and full uint32 target IDs.
// Search, safe-location, forced actions and transition events have explicit
// owners: missing ones fail without pretending that a move completed.
export async function executeMoveToPoint(actor,node,p){
  if(integer(await p.dead(actor),'dead flag')===1||integer(await p.dying(actor),'dying flag')===1||!actor.nativePathInfo)return 3;
  const path=actor.nativePathInfo,goal=[0,1,2].map(i=>f(actionParameter(node,i))),goalArea=actionParameter(node,3)>>>0;
  if(!goal.every(Number.isFinite))throw new Error('Native move goal is unavailable');
  let targetId=node.parameterCount>=5?actionParameter(node,4)>>>0:invalid;
  await p.plot(path,1000); // Native first plot occurs even before flags/target lookup.
  const flags=node.parameterCount>5?integer(actionParameter(node,5),'flags'):0;
  let running=flags&1;const clientPath=(flags>>1)&1,fractional=(flags>>3)&1,offset=(flags>>4)&7,field7=(flags>>7)&3,rawPoint=(flags>>9)&1;
  if(await p.client(actor.id)&&targetId!==invalid)running=1;
  if(integer(actor.nativeField76c,'field +76c')===1)running=0;
  let stop=node.parameterCount>=7?f(actionParameter(node,6)):0;
  const sequence=node.parameterCount>=8?integer(actionParameter(node,7),'sequence'):0,forced=node.parameterCount>=9?f(actionParameter(node,8)):0;
  if(![stop,forced].every(Number.isFinite))throw new Error('Native move ranges are unavailable');
  const requeue=async(point,area=goalArea,forceRaw=rawPoint)=>{
    await addMoveToPointFront(actor,node.groupId,render(point),area,targetId,running,stop,0,clientPath,sequence,offset,field7,fractional,forceRaw,p);return 2;
  };
  if((flags&4)!==0&&forced>0){
    await required(p,'forcedAction')(actor,node.groupId,goalArea,render(goal),targetId,forced);return requeue(goal);
  }
  const tolerance=f(.0001),target=await p.object(targetId);
  if(target?.objectType===5){
    if(await p.hasModule()){
      const targetArea=await p.area(target);
      if(!targetArea){
        const stored=native(target.nativeMovementGoal),area=integer(target.nativeMovementAreaId,'target stored area')>>>0;
        if(area!==goalArea||distance(stored,goal)>4)return requeue(stored,area);
      }else{
        const destination=native(target.position);
        if(offset!==0){
          targetId=invalid;
          if(offset===1||offset===2){const orientation=native(target.orientation),scale=f(stop*3);
            for(let i=0;i<3;i++){const amount=f(scale*orientation[i]);destination[i]=offset===1?f(destination[i]-amount):f(amount+destination[i]);}}
        }
        const trackingTolerance=Math.max(4,f(distance(native(actor.position),destination)/f(6.25)));
        if(targetArea.id!==goalArea||distance(goal,destination)>trackingTolerance){
          const original=native(target.position),oldDistance=distance(original,goal),out={point:render(destination)};
          await required(p,'safeLocation')(await p.area(target),render(destination),20,path,1,out);
          const safe=native(out.point);if(distance(native(target.position),safe)<oldDistance)return requeue(safe,targetArea.id);
        }
        const out={point:[0,0,0],range:0};await p.useRange(actor,targetId,out);
        if(integer(await p.inUseRange(actor,targetId,f(f(stop-f(out.range))-f(.1)),0),'use range')!==0){
          path.resetAtEnd();await p.setAnimation(actor,0);return 2;
        }
      }
    }
  }else if(target?.objectType===7){
    if(integer(await required(p,'transitionTrigger')(target),'trigger transition flag')!==0){
      const nearest=native(await required(p,'triggerPoint')(target,actor.position.slice()));
      const direction=normalize(native(actor.position).map((v,i)=>f(v-nearest[i])));
      targetId=invalid;return requeue(nearest.map((v,i)=>f(v+f(direction[i]*f(.5)))));
    }
    if(integer(await p.inUseRange(actor,targetId,0,0),'trigger use range')!==0){
      await required(p,'useEvent')(actor.id,targetId,{scriptEvent:30,objectIds:[actor.id]});await deleteMatchingMoveFollowup(actor,targetId,node.groupId);return 2;
    }
  }else if(target?.objectType===9||target?.objectType===10){
    if(target.objectType===10&&await required(p,'clickable')(target)!==0&&await p.inUseRange(actor,targetId,0,0)!==0){
      if((integer(await required(p,'openState')(target),'door open state')&255)===0){
        await required(p,'blockedEvent')(targetId,actor.id,{scriptEvent:31});return 1;
      }
      await required(p,'useEvent')(actor.id,targetId,{scriptEvent:30,objectIds:[actor.id]});await p.setAnimation(actor,0);
      path.resetGrid();path.resetWaypoints();path.resetInterTile();await deleteMatchingMoveFollowup(actor,targetId,node.groupId);return 2;
    }
    if(rawPoint===0){
      const out={point:[0,0,0],range:0};await p.useRange(actor,targetId,out);const usePoint=native(out.point);
      if(stop<f(out.range)||distance(usePoint,goal)>=tolerance){stop=Math.max(stop,f(out.range));return requeue(usePoint,goalArea,1);}
    }
  }
  if((integer(actor.nativeMovementFlags8d4,'movement flags')&2)===0){
    if(clientPath!==0)await required(p,'terminateClientPath')(actor,sequence);
    await p.setAnimation(actor,1);return 3;
  }
  const area=await p.area(actor);if(!area)return 1;
  const current=native(actor.position),dx=f(goal[0]-current[0]),dy=f(goal[1]-current[1]);
  if(area.id===goalArea&&f(f(dy*dy)+f(dx*dx))<=tolerance){
    if(integer(await required(p,'safePoint')(await p.area(actor),render(goal),path,0),'safe point')!==0)await p.setPosition(actor,render(goal),0);
    await p.setAnimation(actor,1);return 2;
  }
  path.raw.setInt32(0,clientPath,true);path.raw.setUint32(0x24,actor.id,true);path.field28=targetId;actor.nativeField8f4=0;
  const reversed=path.raw.getInt32(0x74,true)!==0,stored=read(path,reversed?0x64:0x4c),storedArea=path.raw.getUint32(reversed?0x70:0x60,true);
  // The native f64 constant is exactly0.008999999798834325, not decimal.009.
  if(storedArea!==goalArea||distance(goal,stored)>=tolerance||Math.abs(f(path.raw.getFloat32(0x58,true)-stop))>=0.008999999798834325){
    write(path,0x4c,goal);path.raw.setUint32(0x60,goalArea,true);path.raw.setFloat32(0x58,stop,true);path.computeGridTolerance();
    write(path,0x64,current);path.raw.setUint32(0x70,actor.areaId,true);path.raw.setInt32(0x48,1,true);path.raw.setInt32(0x78,0,true);
  }
  if(path.raw.getInt32(0x78,true)===0){
    path.raw.setInt32(0x1a0,fractional,true);const result=integer(await p.plot(path,1000),'plot result');path.raw.setInt32(0x1a0,0,true);
    if(result===2){
      if(path.field28!==targetId)node.parameterData[4]=path.field28|0;
      path.raw.setUint32(0x20,sequence&255,true);path.raw.setInt32(0x98,0,true);
    }else if(result===3){
      path.raw.setUint32(0x20,sequence&255,true);await p.setAnimation(actor,0);
      if(clientPath!==0)await required(p,'terminateClientPath')(actor,sequence);
      write(path,0x4c,native(actor.position));const currentArea=await p.area(actor);if(!currentArea)throw new Error('Native failed path actor area disappeared');
      path.raw.setUint32(0x60,currentArea.id,true);await addPathfindingWaitFront(actor,node.groupId,p);return 3;
    }else return result;
  }
  await p.setAnimation(actor,running?4:2);await required(p,'activityManager')(actor,8);
  return integer(await p.walk(actor,node.groupId),'walk result');
}
