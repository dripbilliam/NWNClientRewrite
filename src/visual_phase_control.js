const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual phase provider ${name} is unavailable`);return p[name](...args);};
// These owners use CVTTSS2SI to a64-bit register, THEN store its lowDWORD.
// A32-bit conversion would incorrectly reject otherwise valid long clips.
export function visualMillisecondsLong(seconds){const value=f(f(seconds)*1000);return Number.isFinite(value)&&value>=-(2**63)&&value<2**63?Math.trunc(value):-(2**63);}
export const visualMilliseconds=seconds=>visualMillisecondsLong(seconds)>>>0;
const word=(e,i)=>e.programsD0[i]&65535;
function visualString(e,column,p){const entry=call(p,'visualString',e.visualF8&65535,column);return entry.found?entry.value:'';}
function targetRender(e,p){const target=call(p,'clientObject',e.target54);return target?call(p,'renderObject',target):null;}
function positional(e,name,render,p){call(p,'positionalSound',name,render.position38.map(f),f(1.5),11,0,0);}

// Complete start/restart140970e20..14097152b, including geometry phases,
// program priority, table-driven camera shake and impact/duration audio.
export function startVisualPhases(e,p){
  if(!e.closedEc||e.finishedF4)return;
  e.startedF0=1;
  for(let i=0;i<3;i++){
    e.modelRemaining5c[i]=0;const model=e.models88[i];if(!model)continue;
    if(call(p,'playAnimation',model,'impact',1,1,0)){
      e.modelStates68[i]=1;const info=call(p,'animationInfo',e.models88[i],'impact');e.modelRemaining5c[i]=visualMilliseconds(info.length);
    }else if((e.durationFc&255)===1){e.modelStates68[i]=2;call(p,'playAnimation',e.models88[i],'duration',1,0,0);}
    else{e.modelStates68[i]=1;e.modelRemaining5c[i]=1000;}
  }
  e.programPhaseFa=0;
  for(let i=0;i<3;i++)if(word(e,i)!==65535){
    call(p,'clearProgram',e);call(p,'loadProgram',e,word(e,i));call(p,'startProgram',e,word(e,i));
    e.programPhaseFa=i+1;e.programType10d=call(p,'programType',e,word(e,i))&255;break;
  }
  if((e.scope10c&255)===0){
    const type=call(p,'visualInt',e.visualF8&65535,'ShakeType'),duration=call(p,'visualFloat',e.visualF8&65535,'ShakeDuration'),delay=call(p,'visualFloat',e.visualF8&65535,'ShakeDelay');
    const kind=type.found?type.value|0:0,seconds=duration.found?f(duration.value):0,wait=delay.found?f(delay.value):0;
    if(call(p,'controlledClient')){
      if(kind===1)call(p,'shakeOnce',call(p,'controlledClient'),visualMillisecondsLong(wait));
      else if(kind===2)call(p,'shakeLoop',call(p,'controlledClient'),visualMillisecondsLong(wait),visualMillisecondsLong(seconds));
    }
  }
  const render=targetRender(e,p),impact=visualString(e,'SoundImpact',p),duration=visualString(e,'SoundDuration',p);
  if(render)positional(e,impact,render,p);
  e.sound118=call(p,'createSound',duration);
  if(e.sound118){call(p,'soundSetting',e.sound118,'setting1401d9e90',1);call(p,'soundSetting',e.sound118,'setting1401da060',11);call(p,'soundSetting',e.sound118,'setting1401d9f90',1);call(p,'playSound',e.sound118);}
  e.closedEc=0;
}

// Complete stop/cessation140971530..140971955. Notably the original writes
// c0/dc (the FIRST model's retirement fields) inside every model iteration;
// preserve this rather than replacing it with a more regular per-slot loop.
export function stopVisualPhases(e,requested,p){
  requested|=0;e.finishedF4=requested;if(e.closedEc)return;
  e.closedEc=1;let played=false;
  for(let i=0;i<3;i++){
    e.modelRemaining5c[i]=0;const model=e.models88[i];if(!model)continue;
    const info=call(p,'animationInfo',model,'cessation');
    if(call(p,'playAnimation',e.models88[i],'cessation',1,1,0)){
      e.modelStates68[i]=3;const length=visualMilliseconds(info.length);e.modelRemaining5c[i]=length;e.retireRemainingC0[0]=(length+3000)>>>0;played=true;
    }else{e.retiredDc[0]=1;e.retireRemainingC0[0]=3000;}
  }
  if(requested!==0&&!played)e.retiringE8=1;
  if((e.programPhaseFa&255)===2){
    if((call(p,'programType',e,word(e,1))&255)!==4||(call(p,'programType',e,word(e,2))&255)!==4){
      call(p,'stopProgram',e,word(e,1));
      if(e.proceduralB8){
        call(p,'detachProcedural',e.proceduralB8,0,0,0);call(p,'unsceneProcedural',e.proceduralB8,0);
        if(e.proceduralB8)call(p,'destroyProcedural',e.proceduralB8,1);e.proceduralB8=null;
      }
    }
    if(word(e,2)===65535)e.programPhaseFa=0;
    else{e.programPhaseFa=3;e.programType10d=call(p,'programType',e,word(e,2))&255;e.programRemainingCc=word(e,2)===65535?0:1000;}
  }
  if(word(e,2)!==65535){
    if((call(p,'programType',e,word(e,1))&255)!==4||(call(p,'programType',e,word(e,2))&255)!==4)call(p,'loadProgram',e,word(e,2));
    call(p,'startProgram',e,word(e,2));
  }
  const render=targetRender(e,p),cessation=visualString(e,'SoundCessation',p);if(render)positional(e,cessation,render,p);
  if(e.sound118){call(p,'stopSound',e.sound118);if(e.sound118)call(p,'destroySound',e.sound118,1);e.sound118=null;}
  if(e.attached114)call(p,'detach',e);
}
