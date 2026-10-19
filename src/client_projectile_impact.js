import {clientProjectileImpactQuaternion} from './client_projectile_orientation.js';
const f=Math.fround,call=(p,key,...args)=>{if(typeof p[key]!=='function')throw new Error(`Native projectile impact provider ${key} is unavailable`);return p[key](...args);};

// AIUpdate983e2e..9841d2, entered only for attachOnImpact exactly1.
// Model handle78 and client flag28 are distinct from the ready model virtual.
export function attachClientProjectileImpact(state,p){
 const found=call(p,'getObject',state.targetId>>>0);
 if(found.status===0){
  const target=found.object,result=state.result&255;let anchor=null;
  if(result===0){
   if(call(p,'modelHandle',target)){
    if(call(p,'field28',target)===0)anchor=call(p,'model',target,255,1);
    else state.impactDuration=0;
   }
  }else if(result===2){
   const creature=call(p,'creature',target),id=call(p,'equipped',creature,0x20),item=call(p,'item',id);
   if(item&&call(p,'weaponType',item)===7){
    if(call(p,'field28',target)===0)anchor=call(p,'itemModel',item,255,1);
    else state.impactDuration=0;
   }
  }
  const model=call(p,'model',state,255,1);
  if(anchor&&model&&result!==1&&result!==3){
   if(result===0||result===2){
    const part=result===0?state.impactNode:`imp_shield_${((call(p,'random')|0)%2)+1}`;
    call(p,'attach',model,anchor,part,0);
    const position=[0,0,0],quaternion=[1,0,0,0];call(p,'nodePose',model,'root',position,quaternion);
    call(p,'setNodePose',model,'root',position,clientProjectileImpactQuaternion(state.orientation));
   }
  }
  if(call(p,'creature',target)&&(state.rangedEffect&255)!==0)call(p,'rangedImpact',target,state);
 }
 state.remaining=state.impactDuration>>>0;
}
