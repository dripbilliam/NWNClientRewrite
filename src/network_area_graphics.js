// GPU completion is a presentation barrier, not a network-import barrier.
// Retain every polled program/material owner even if its area is superseded.
export function startNetworkAreaGraphics(owner,{prepare,current,complete,failed,retirement,ended}){
 owner.graphicsPending=true;const release=retirement.begin();let gated=true;
 const finishGate=()=>{if(!gated)return;gated=false;owner.graphicsPending=false;ended();};owner.cancelGraphics=finishGate;
 const live=()=>!owner.closed&&current();
 const work=Promise.resolve().then(()=>{if(live())return prepare();return false;}).then(async result=>{if(!live()||result===false)return false;await complete();return true;}).catch(async error=>{if(live())await failed(error);return false;}).finally(()=>{
  try{release();}finally{finishGate();if(owner.cancelGraphics===finishGate)owner.cancelGraphics=null;}
 });
 owner.graphicsWork=work;return work;
}
