import {addWorldTimes,compareWorldTimes} from './world_timer.js';
const f=Math.fround;
const empty=()=>({active:0,animation:0,start:{day:0,time:0},duration:500,speed:1,record:null});

// Client object 7635a0/7632d0/763fb0. Records have pointer identity: identical
// attacks in different server updates must not collapse into one animation.
// Clock and storage are presentation state, never authoritative combat state.
export class ClientAnimationQueue {
 constructor(dayLength){this.dayLength=dayLength>>>0;this.entries=[];this.count=0;}
 insert({animation,duration,speed,record=null,delay=0},now){
  if(record!==null&&this.entries.some(e=>e.record===record))return false;
  // Native BYTE count wraps at256; report unsupported overflow before it can
  // corrupt presentation rather than silently discarding or replacing cues.
  if(this.count===255)throw new Error('Native animation queue BYTE capacity exceeded');
  if(this.count===this.entries.length)this.entries.push(...Array.from({length:8},empty));
  const start=addWorldTimes(now,{day:0,time:delay>>>0},this.dayLength);
  if(start.status!==0)throw new Error('Native animation queue start time is invalid');
  let index=this.count;
  while(index>0&&compareWorldTimes(start,this.entries[index-1].start,this.dayLength)===-1){this.entries[index]=this.entries[index-1];index--;}
  this.entries[index]={active:1,animation:animation&65535,start:{day:start.day,time:start.time},duration:duration>>>0,speed:f(speed),record};this.count++;return true;
 }
 next(now){
  const e=this.entries[0];
  const none=()=>({ready:0,animation:0,speed:1,duration:500,record:null});
  if(!e?.active)return none();
  // GetTimeDifferenceFromWorldTime597090 uses one time-of-day borrow. The
  // day comparison rejects future entries; it does not multiply whole days.
  const start=e.start,length=this.dayLength;
  let elapsed=0;
  if(!(now.time<length&&start.time<length&&(now.day<start.day||now.day===start.day&&now.time<start.time))){elapsed=(now.time-start.time)>>>0;if(elapsed>=length)elapsed=(elapsed+length)>>>0;}
  if(elapsed===0&&compareWorldTimes(now,start,length)===-1)return none();
  const duration=Math.max(50,(e.duration-elapsed)>>>0);
  return{ready:1,animation:e.animation,speed:f(f(f(e.duration)*e.speed)/f(duration)),duration,record:e.record};
 }
 remove(){if(!this.count)return;for(let i=1;i<this.count;i++)this.entries[i-1]=this.entries[i];this.entries[--this.count]=empty();}
 clear(){this.entries=[];this.count=0;}
 snapshot(){return{capacity:this.entries.length,entries:this.entries.slice(0,this.count).map(({active,...e})=>({...e,start:{...e.start}}))};}
}
