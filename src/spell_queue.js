import {OBJECT_INVALID} from './game_object_array.js';
import {nativeFloatEntry} from './movement_rate.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell queue ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell queue provider ${n} is unavailable`);return p[n];};
const bits=value=>{const data=new DataView(new ArrayBuffer(4));data.setFloat32(0,value,true);return data.getUint32(0,true);};
const param=(type,value)=>({type,value});
const pointParams=point=>point.map(value=>param(2,bits(value)));

// CNWRules ctor1402a24d7..1402a2599: five physical Ranges rows,
// successful PrimaryRange FLOAT reads replace the zero initialized cell.
export function loadSpellRanges(rules,p={}){
  if(!rules.ranges)throw new Error('Native Ranges spell table is unavailable');
  return Array.from({length:5},(_,index)=>{const entry=nativeFloatEntry(rules.ranges,index,'PrimaryRange');
    if(!entry.found)p.warning?.('Failed to load spell ranges.');return entry.found?entry.value:0;});
}
// ComputeSpellRange140388d20. Exact P is rewritten to T before dispatch.
// Each geometry personal-space cell contributes (space -0.1), in order.
export function computeSpellRange(actor,text,targetId,p){
  const range=String(text??'').split('\0')[0],key=range==='P'?'T':range;
  const index=({P:0,T:1,S:2,M:3,L:4})[key],ranges=p.ranges;
  if(!Array.isArray(ranges)||ranges.length!==5)throw new Error('Native spell range cache is unavailable');
  let value=index===undefined?0:f(ranges[index]);
  value=f(value+f(f(required(p,'personalSpace')(actor))-f(.1)));
  const target=required(p,'creature')(targetId>>>0);
  if(target)value=f(value+f(f(p.personalSpace(target))-f(.1)));
  return value;
}

// AddCastSpellActions14037d540. Positions here are native XYZ; the live
// adapter owns renderer-coordinate conversion. Preserve queue group sentinel
// and twelve physical types, including raw flags and FLOAT bit cells.
export async function addCastSpellActions(actor,{spellId,classIndex,domainLevel=0,metamagic=0,spontaneous=0,
  position,targetId=OBJECT_INVALID,location=0,front=0,cheat=0,path=0,instant=0,featId=-1,casterLevel=255},p){
  spellId=integer(spellId,'spell ID')>>>0;classIndex=integer(classIndex,'class index');
  if((integer(actor.nativeField771,'creature state')&255)===5){await required(p,'feedback')(actor,7);return 0;}
  actor.spellActionTargetId=actor.nativeTarget740=OBJECT_INVALID;
  if(cheat===0&&spontaneous===0&&classIndex!==255){
    if(classIndex===254){if(required(p,'abilityReady')(actor,spellId)===0)return 0;}
    else if((required(p,'uses')(actor,spellId,classIndex&255,domainLevel&255,metamagic&255)&255)===0)return 0;
  }
  if(integer(actor.nativeEquipmentLock97c,'override flag')!==0&&[actor.nativeSpellOverride9e8,actor.nativeSpellOverride9ec,actor.nativeSpellOverride9f0].some(id=>(integer(id,'override spell ID')>>>0)===spellId))classIndex=255;
  targetId=integer(targetId,'target ID')>>>0;const target=required(p,'object')(targetId);
  if(required(p,'dm')(actor)===0&&cheat===0&&target&&required(p,'asCreature')(target)&&target.id!==actor.id){
    const visible=required(p,'visibility')(actor,targetId);if(visible===null||(visible&12)===4||(visible&17)===16)return 0;
  }
  if(!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite))throw new Error('Native spell queue position is unavailable');
  const storedPoint=position.map(f);let carried=false;
  if(targetId!==OBJECT_INVALID){
    if(!target||target.objectType<=4)return 0;
    const area=required(p,'area')(target);position.splice(0,3,...required(p,'position')(target).map(f));
    if(!area||area!==p.area(actor)){
      if(target.objectType!==6||required(p,'possessor')(target)!==actor.id)return 0;
      p.area(actor);carried=true;position.splice(0,3,...p.position(actor).map(f));
    }
  }
  const spell=required(p,'spell')(spellId);if(!spell)return 0;
  if(!required(p,'area')(actor)||integer(actor.nativeFieldEc,'commandability')===0)return 0;
  const area=p.area(actor),range=f(required(p,'range')(actor,spell,targetId));
  let flags=integer(path,'projectile path')&255;if(cheat!==0)flags|=0x80000000;if(instant!==0)flags|=0x40000000;
  const cast=[param(1,spellId),param(1,classIndex),param(1,domainLevel),param(1,metamagic),param(1,spontaneous),param(3,targetId),
    ...pointParams(storedPoint),param(1,flags),param(1,featId),param(1,casterLevel&255)];
  const queue=(id,group,params=[],at=front!==0)=>required(p,'queue')(actor,id,group,params,Boolean(at));
  if(instant===1){await queue(15,65535,cast);return 1;}
  const turn=(group)=>targetId===OBJECT_INVALID?queue(49,group,pointParams(storedPoint)):queue(19,group,[param(3,targetId)]);
  const check=(group,afterMove)=>targetId===OBJECT_INVALID?queue(18,group,[...pointParams(storedPoint),param(3,area.id),param(3,targetId),param(1,1),param(2,bits(range))]):
    queue(17,group,[param(3,targetId),param(1,1),param(2,bits(range)),param(2,bits(range)),param(1,1),...(afterMove?[param(1,1)]:[])]);
  const origin=required(p,'position')(actor).map(f),d=position.map((v,i)=>f(v-origin[i]));
  const distance=f(f(f(d[1]*d[1])+f(d[0]*d[0]))+f(d[2]*d[2])),outside=distance>f(range*range);
  if(front!==0){
    await queue(15,65535,cast);await queue(16,65534);
    if(!carried){await turn(65534);await check(65534,false);
      if(outside){await queue(1,65534,[...pointParams(position),param(3,area.id),param(3,targetId),param(1,1),param(2,bits(range)),param(1,0),param(2,bits(0))]);await required(p,'setLock')(actor,OBJECT_INVALID);}}
  }else{
    let group=65535;
    if(!carried){
      if(outside){await required(p,'move')(actor,65535,[...position],area.id,targetId,1,range,0,0,0,0,0,0,0);group=65534;await check(group,true);}
      await turn(group);group=65534;
    }
    await queue(16,group);await queue(15,65534,cast);
  }
  actor.spellActionTargetId=location!==0?p.area(actor).id:targetId;return 1;
}

// AIActionWaitForEndOfRound1403cf7e0, profiling disabled. Only a due type2
// spell action anywhere in the round list bypasses an active round's wait.
export async function waitForCastRound(actor,p){
  if(await required(p,'dead')(actor)===1||await required(p,'dying')(actor)===1)return 3;
  if(Number(actor.combatRound.started)===1&&await required(p,'spellPending')(actor)===0)return 1;
  return 2;
}
export const spellActionPending=round=>Number(round.actions.some(a=>(a.time|0)<=(round.timer|0)&&(a.nativeActionType&255)===2));
