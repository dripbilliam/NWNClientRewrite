const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native visual phase provider ${name} is unavailable`);return p[name](...args);};
const f=Math.fround;
// Complete visual-on-object phase update140971a80..140971e10. Time and
// countdowns are native unsigned milliseconds. Model/program/audio services
// remain explicit boundaries; this owner never rewrites gameplay effects.
export function updateVisualPhases(e,delta,p){
  delta>>>=0;
  const object=call(p,'clientObject',e.target54);if(!object)return;
  const render=call(p,'renderObject',object);if(!render)return;
  const phase=e.programPhaseFa&255;
  if(phase===1||phase===3){
    const remaining=e.programRemainingCc>>>0;
    if(remaining<=delta){
      e.programRemainingCc=0;
      if(phase===1){
        call(p,'stopProgram',e,e.programsD0[0]&65535);call(p,'clearProgram',e);
        if((e.durationFc&255)===0){e.programPhaseFa=0;e.finishedF4=1;}
        else{
          e.programPhaseFa=2;e.programType10d=call(p,'programType',e,e.programsD0[1]&65535)&255;
          call(p,'loadProgram',e,e.programsD0[1]&65535);call(p,'startProgram',e,e.programsD0[1]&65535);
          if(!e.attached114)call(p,'detach',e);
        }
      }else{
        if(e.attached114)call(p,'stopProgram',e,e.programsD0[2]&65535);
        call(p,'clearProgram',e);e.programPhaseFa=0;
      }
    }else{
      e.programRemainingCc=(remaining-delta)>>>0;
      if(e.updateProgramD8&&e.attached114)call(p,'updateProgram',e,call(p,'currentProgram',e),delta);
    }
  }else if(phase===2&&e.updateProgramD8&&e.attached114)call(p,'updateProgram',e,e.programsD0[1]&65535,delta);
  for(let i=0;i<3;i++){
    const remaining=e.modelRemaining5c[i]>>>0;if(remaining===0)continue;
    e.finishedF4=0;
    if(remaining>delta){e.modelRemaining5c[i]=(remaining-delta)>>>0;continue;}
    e.modelRemaining5c[i]=0;
    const state=e.modelStates68[i]&65535;
    if(state===1&&(e.durationFc&255)!==0){e.modelStates68[i]=2;call(p,'playAnimation',e.models88[i],'duration',1,0,0);}
    else if(state===1||state===3){
      // Native compares object pointers, not the current slot index. Aliased
      // model slots therefore reset the FIRST equal retirement countdown.
      const index=e.models88.indexOf(e.models88[i]);if(index>=0)e.retireRemainingC0[index]=3000;
      e.finishedF4=1;e.retiringE8=1;
    }
  }
  if(e.sound118)call(p,'updateSound',e.sound118,render.position38.map(f),0);
  if(!e.retiringE8)return;
  for(let i=0;i<3;i++)if(!e.retiredDc[i]){
    const remaining=e.retireRemainingC0[i]>>>0;
    if(remaining<=delta)e.retiredDc[i]=1;else e.retireRemainingC0[i]=(remaining-delta)>>>0;
  }
}
