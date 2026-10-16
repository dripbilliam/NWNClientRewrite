const f=Math.fround,call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native model playback provider ${name} is unavailable`);return p[name](...args);};
const lower=value=>String(value).split('\0')[0].replace(/[A-Z]/g,c=>c.toLowerCase());
const remove=(runs,run)=>{const i=runs.indexOf(run);if(i>=0)runs.splice(i,1);};
// Complete Gob::PlayAnimation140052580..140052a22. Resource lookup, scale,
// allocation/destruction and event dispatch are explicit lower services.
// Runs retain native order and identity; restarting an existing run preserves
// its current time and weight rather than resetting it to the new clip's start.
export function playModelAnimation(gob,name,speed,flags,start,p){
 const runs=gob.runsE0;flags|=0;speed=f(speed);start=f(start);
 if(name===null||name===undefined||String(name).split('\0')[0]===''||lower(name)==='null'){
  for(let i=runs.length-1;i>=0;i--)if(runs[i])call(p,'destroyRun',runs[i],40);runs.length=0;return 1;
 }
 name=String(name).split('\0')[0];let run=null;
 if(!(flags&64))for(let i=runs.length-1;i>=0;i--)if(lower(runs[i].clip0.name)===lower(name)){
  run=runs[i];if(flags&512){run.flagsC|=513;return 1;}remove(runs,run);break;
 }
 if(!run&&lower(name)==='current'){
  run=runs.find(value=>!(value.flagsC&40))??null;if(run)remove(runs,run);
 }
 if(flags&128){if(!run)return 0;call(p,'event',`done${run.clip0.name}`,0);call(p,'destroyRun',run,40);return 1;}
 let model=gob.model80,clip=model?call(p,'findAnimation',model,name):null;
 if(!clip){model=gob.model68;clip=call(p,'findAnimation',model,name);}
 // SSE MAXSS/MINSS return their second operand for unordered comparisons.
 let offset=0>start?0:start;if(clip)offset=f(clip.length90)<offset?f(clip.length90):offset;
 if(!run){
  if(!clip)return 0;
  run=call(p,'createRun',clip);
  if(!run)throw new Error('Native AnimRun allocation failed before an unchecked dereference');
  Object.assign(run,{clip0:clip,speed8:1,flagsC:0,previous10:0,time14:0,weight18:1,transition1c:0,scale20:1,done24:0});
  if(speed<0)run.time14=f(f(clip.length90)+f(.00001));
  if(speed>0)run.time14=f(-.00001);
  if(offset!==0)run.time14=offset;
  if(!(flags&2)){run.weight18=0;run.transition1c=f(clip.transition94);}
 }
 run.scale20=f(call(p,'animationScale',model,clip));run.done24=0;
 const scale=f(call(p,'playbackScale',gob));run.flagsC=flags;run.speed8=f(scale*speed);
 let index=0;
 if(!(flags&8))while(index<runs.length){const old=runs[index].flagsC;if(!(old&8)&&((flags&32)||!(old&32)))break;index++;}
 runs.splice(index,0,run);
 if((flags&16)&&runs.length>index+1)run.time14=runs[index+1].time14;
 else if(!(flags&40)){
  while(runs.length>index+1){const old=runs[index+1],done=`done${old.clip0.name}`;remove(runs,old);call(p,'event',done,0);call(p,'destroyRun',old,40);}
  call(p,'event',`start${run.clip0.name}`,0);
 }
 return 1;
}
