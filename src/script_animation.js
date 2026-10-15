import {addObjectAction,actionParameter,disposeObjectAction} from './object_actions.js';
import {subtractWorldTimes} from './reputation.js';
import {scriptAnimationMap} from './script_animation_map.js';
const f=Math.fround;
const bits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getInt32(0,true);};
const uintFromFloat=value=>Number(BigInt.asUintN(32,Number.isFinite(value)&&value>=-(2**63)&&value<2**63?BigInt(Math.trunc(value)):-(1n<<63n)));

// ExecuteCommandPlayAnimation140538060. Creature/script animation IDs and
// the stored native animation IDs are separate domains.
export async function scriptPlayAnimation(actor,id,speed,duration,immediate,p){
  if(!actor||actor.objectType<=4)return;
  id|=0;let native=0;
  if(actor.objectType===5){
    native=scriptAnimationMap[id]??0;
    if(id===112||id===113){
      const model=await p.modelType(actor);
      native=model.includes('P')||model.includes('F')?(id===112?71:70):0;
    }
  }else if(actor.objectType===9)native=id>=200&&id<=203?id-200+73:0;
  else if(actor.objectType===10){
    if(id<204||id>207)return;
    if(!Number.isInteger(actor.nativeDoorField498))throw new Error('Native scripted door animation field498 is unavailable');
    if(actor.nativeDoorField498===0)return;
    actor.nativeDoorField498=id===207?0:1;
    await p.setAnimation(actor,({204:22,205:50,206:51,207:72})[id]);
    await p.updateAutomaps(actor);return;
  }else return;
  if(actor.nativeFieldEc===0)return;
  if(immediate)await p.clearActions(actor);
  addObjectAction(actor.objectActionState,6,65535,[{type:1,value:native},{type:2,value:bits(speed)},
    {type:2,value:bits(duration)},{type:1,value:1}],Boolean(immediate));
}

// AIActionPlayAnimation1404a4700 (verified body1404a4d93..1404a5029).
// Durations are native fixed milliseconds; the stored speed is signed, but
// its absolute value scales action lifetime. This is independent of MDL time.
export async function executeScriptAnimation(actor,node,p){
  if(await p.dead(actor)===1||await p.dying(actor)===1)return 3;
  const id=actionParameter(node,0)|0,speed=f(actionParameter(node,1)),duration=f(actionParameter(node,2));
  const now=await p.worldTime(),state=actor.objectActionState;
  if(actionParameter(node,3)===1){state.startDay=now.day;state.startTime=now.time;node.parameterData[3]=0;}
  const elapsed=subtractWorldTimes(now,{day:state.startDay,time:state.startTime},p.dayLength);
  if(elapsed.status!==0)throw new Error('Native animation time subtraction left uninitialized output');
  if(duration>=30){
    const list=state.list;
    while(list.head){
      const next=list.head.action;
      if(next.actionId!==6||actionParameter(next,0)!==id||actionParameter(next,1)!==speed)break;
      await disposeObjectAction(list.shift(),p.deleteSituation);
    }
  }
  const short=id&65535,offset=(id-28)&65535;
  let ms=1000;
  if(short===0||offset<44&&(0xc000f003e97n>>BigInt(offset)&1n))ms=2000;
  else if(short===36||short===46)ms=1000;
  else if(short===44||short===45)ms=1734;
  else if(short===47)ms=1500;
  else if(((short-56)&0xfffd)===0)ms=4000;
  else if(short===57)ms=2834;
  else if(short===33)ms=7000;
  else if(short===34||short===60)ms=500;
  else if(short===59)ms=867;
  if(Math.abs(speed)!==0)ms=uintFromFloat(f(f(ms)/Math.abs(speed)));
  if(duration>0&&((id>>>0)>56||!(0x1e0702c60000000n>>BigInt(id)&1n)))ms=uintFromFloat(f(duration*f(1000)));
  if(elapsed.milliseconds<ms){actor.nativeAnimationSpeedDC=speed;await p.setAnimation(actor,short);return 1;}
  if(actor.objectType===5){actor.nativeAnimationSpeedDC=1;await p.setAnimation(actor,1);}
  return 2;
}
