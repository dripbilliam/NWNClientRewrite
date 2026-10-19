const f=Math.fround,call=(p,key,...args)=>{if(typeof p[key]!=='function')throw new Error(`Native client fade provider ${key} is unavailable`);return p[key](...args);};

// CNWCObject765920. State cells104/108 gate the entire request. Display
// virtuals retain their actual offsets; their scene internals are separate.
export function setClientObjectFade(s,target,delay,duration,p){
 if((s.temporary|0)===1||(s.blocked|0)!==0)return;
 s.fadeTarget=target&255;s.delayEnabled=delay|0;s.duration=duration>>>0;
 if(s.delayEnabled!==0)s.since={...call(p,'worldTime')};
 const mode=call(p,'mode')&255;
 if(s.fadeTarget===1){
  if(call(p,'modelHandle',s)){
   if(mode===2){call(p,'display',s,0x210);call(p,'display',s,0x200);s.visible=1;return;}
   if(mode===1&&((call(p,'controlledId')>>>0)===(s.id>>>0))){call(p,'display',s,0x210);call(p,'display',s,0x200);s.visible=1;return;}
   call(p,'display',s,0x218);call(p,'display',s,0x1f8);s.visible=1;
  }
 }else{
  if(call(p,'modelHandle',s)){
   if(mode===2){call(p,'display',s,0x218);call(p,'display',s,0x200);}
   else if(mode===1){call(p,'controlledId');call(p,'display',s,0x218);call(p,'display',s,0x200);}
   else{call(p,'display',s,0x218);call(p,'display',s,0x1f8);}
  }
  s.visible=0;
 }
}

// CNWCObject762e40. Expiry compares only the unsigned millisecond remainder,
// even if SubtractWorldTimes reports whole days. No invented wall-clock timeout.
export function updateClientObjectFade(s,p){
 if((s.fadeState&255)===(s.fadeTarget&255)){
  if((s.delayEnabled|0)!==0){const now=call(p,'worldTime'),elapsed=call(p,'difference',now,s.since);if(!Number.isInteger(elapsed.time))throw new Error('Native client fade time subtraction did not produce a time');if((s.duration>>>0)<=(elapsed.time>>>0))return 1;}
 }else{
  const microseconds=BigInt.asUintN(64,call(p,'snapshotDifference')),milliseconds=Number(BigInt.asUintN(32,microseconds/1000n));
  if((s.fadeTarget&255)===1){
   const target=f(call(p,'targetAlpha',s));
   if(f(s.opacity)<target){s.fadeState=2;s.opacity=f(f(f(milliseconds)/2000)+f(s.opacity));}
   else{s.fadeState=1;s.opacity=f(call(p,'targetAlpha',s));}
  }else if((s.fadeTarget&255)===0){
   const target=f(call(p,'targetAlpha',s));
   if(target<f(s.opacity)){s.fadeState=3;s.opacity=f(f(s.opacity)-f(f(milliseconds)/2000));}
   else{s.opacity=f(call(p,'targetAlpha',s));s.fadeState=0;if((s.delayEnabled|0)!==0){s.since={...call(p,'worldTime')};call(p,'handleScene',s,0);}}
  }
  if(s.opacity<0)s.opacity=0;else if(s.opacity>1)s.opacity=1;
  if(call(p,'modelHandle',s))call(p,'alpha',s,f(s.opacity),255);
 }
 return 0;
}
