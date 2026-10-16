const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native model run clock provider ${name} is unavailable`);return p[name](...args);};
const remove=(runs,run)=>{const i=runs.indexOf(run);if(i>=0)runs.splice(i,1);};
// Gob::Animate run stage14004e455..14004e8f5. The complete outer owner is
// captured separately; scene-sequence/visibility, attachment/sound, profiling,
// pose sampling and destruction-handle gates remain the caller's obligation.
// This stage retains reverse physical order, queued flags, terminal-frame
// delay, native loop overshoot clamps and blend arithmetic.
export function advanceModelRuns(gob,delta,p){
 delta=f(delta);const runs=gob.runsE0,last=runs.at(-1);
 if(last&&(last.flagsC&32)){last.flagsC=(last.flagsC-32)|0;call(p,'event',`start${last.clip0.name}`,0);}
 for(let i=runs.length-1;i>=0;i--){
  if(i>=runs.length)continue;const run=runs[i];if(run.flagsC&32)continue;
  run.previous10=f(run.time14);run.time14=f(f(run.previous10)+f(f(run.speed8)*delta));
  if(run.flagsC&1){
   if(run.done24){const name=`done${run.clip0.name}`;remove(runs,run);call(p,'event',name,0);call(p,'destroyRun',run,40);continue;}
   let ended=false;
   if(run.time14<0&&run.speed8<=0){run.time14=0;ended=true;}
   else if(run.time14>f(run.clip0.length90)&&run.speed8>=0){run.time14=f(run.clip0.length90);ended=true;}
   if((run.flagsC&512)||ended){
    const next=i>0?runs[i-1]:null;
    if(next&&(next.flagsC&32)){next.flagsC=(next.flagsC-32)|0;call(p,'event',`start${next.clip0.name}`,0);}
    const transition=f(run.transition1c),decrement=transition<=0?2:f(f(delta+delta)/transition);
    run.weight18=f(f(run.weight18)-decrement);
    if(run.weight18<=0){run.weight18=0;run.done24=1;if(transition===0)run.weight18=1;}
   }
  }else{
   if(run.time14<0&&run.speed8<=0){
    if(run.flagsC&4)call(p,'event',`loop${run.clip0.name}`,0);
    run.time14=f(f(run.time14)+f(run.clip0.length90));if(run.time14<0)run.time14=0;
   }
   if(run.time14>f(run.clip0.length90)&&run.speed8>=0){
    if(run.flagsC&4)call(p,'event',`loop${run.clip0.name}`,0);
    run.time14=f(f(run.time14)-f(run.clip0.length90));if(run.time14>f(run.clip0.length90))run.time14=f(run.clip0.length90);
   }
  }
  if(!run.done24&&run.weight18<1){
   const increment=run.transition1c<=0?1:f(delta/f(run.transition1c));run.weight18=f(f(run.weight18)+increment);
   if(run.weight18>1){run.weight18=1;
    if(!(run.flagsC&8))while(runs.length>i+1){const old=runs[i+1];remove(runs,old);if(old)call(p,'destroyRun',old,40);}
   }
  }
  const reverse=run.speed8<0?1:0;
  call(p,'applyClip',run.clip0,run.previous10,run.time14,run.weight18,f(run.scale20),(run.flagsC&256)?run:null,reverse);
  call(p,'animateEvents',run.clip0,run.previous10,run.time14,reverse);
 }
 if(gob.root90){
  call(p,'updateRoot',gob.root90,delta);const old=(gob.period188<<16)>>16;
  gob.period188=((old+1)%5)<<16>>16;if(gob.period188===0)call(p,'periodicUpdate',gob);
 }
}
