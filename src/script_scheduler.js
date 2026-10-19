import {WorldTimer,secondsToWorldDelta,addWorldTimes,compareWorldTimes,subtractWorldTimes} from './world_timer.js';
const uint=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native event ${n} is unavailable`);return v>>>0;};

// Absolute556eb0 scans from the head, before strictly later times. ViaTail
// 556fb0 and Delta5570b0 with time!=0 scan from the tail, after strictly earlier
// times. Equal positive delays are LIFO; delta.time==0 uses the head/FIFO path.
export function insertTimedEvent(events,record,dayLength,fromTail=false){
  if(fromTail){for(let i=events.length-1;i>=0;i--)if(compareWorldTimes(events[i],record,dayLength)===-1){events.splice(i+1,0,record);return;}events.unshift(record);}
  else{const index=events.findIndex(e=>compareWorldTimes(e,record,dayLength)===1);if(index<0)events.push(record);else events.splice(index,0,record);}
}
// EventPending557fe0 and inline UpdateState admit compare<1, including native
// invalid-time result-2. Host monotonic time never owns this decision.
export function timedEventDue(record,now,dayLength){return Boolean(record)&&compareWorldTimes(record,now,dayLength)<1;}
export class ScriptScheduler {
  constructor({validTarget,dispatch,beforePump=()=>{},onError=()=>{},maxEventsPerPump=256,getWorldTimer=null,activePauseState=()=>0,onPausedEvent=()=>{},onRejectedEvent=()=>{}}){
    Object.assign(this,{validTarget,dispatch,beforePump,onError,maxEventsPerPump,getWorldTimer,activePauseState,onPausedEvent,onRejectedEvent});
    this.time=0;this.sequence=0;this.events=[];this.pumping=false;
    // Standalone adapters own a native local clock. ModuleSession supplies the
    // shared cached world timer, which only its host update snapshots.
    this.localTimer=getWorldTimer?null:new WorldTimer(()=>BigInt(Math.trunc(this.time*1000)));
  }
  clock(){if(this.localTimer){this.localTimer.snapshot();return this.localTimer;}const timer=this.getWorldTimer();if(!timer?.time)throw new Error('Native event world timer is unavailable');return timer;}
  worldTime(){return this.clock().time();}
  record(targetId,event,deadline){
    const record={targetId:uint(targetId,'target ID'),event,day:uint(deadline.day,'day'),time:uint(deadline.time,'time'),sequence:this.sequence++};
    // Compatibility/debug projection for unpaused probes; never authority for
    // order/delivery. It moves with pauses and is not a writable timestamp.
    Object.defineProperty(record,'due',{enumerable:true,get:()=>{
      const clock=this.clock(),now=clock.time(),comparison=compareWorldTimes(record,now,clock.dayLength);if(comparison===-2)return NaN;
      const delta=comparison<0?subtractWorldTimes(now,record,clock.dayLength):subtractWorldTimes(record,now,clock.dayLength);
      const distance=delta.day*clock.dayLength+delta.time;return this.time+(comparison<0?-distance:distance);
    }});return record;
  }
  enqueue(targetId,event,seconds=0){
    if(!Number.isFinite(seconds))throw new Error('Invalid event delay');
    const delta=secondsToWorldDelta(seconds,this.clock().secondsPerDay);return this.enqueueDelta(targetId,event,delta.day,delta.time);
  }
  enqueueMilliseconds(targetId,event,milliseconds){
    if(!Number.isInteger(milliseconds)||milliseconds<0||milliseconds>0xffffffff)throw new Error('Invalid event millisecond delay');
    return this.enqueueDelta(targetId,event,0,milliseconds);
  }
  enqueueDelta(targetId,event,day,time){
    const clock=this.clock(),delta={day:uint(day,'delta day'),time:uint(time,'delta time')};targetId=uint(targetId,'target ID');
    if(this.activePauseState()===2&&(delta.day!==0||delta.time!==0))this.onPausedEvent({targetId,event,delta});
    const now=clock.time(),deadline=addWorldTimes(now,delta,clock.dayLength);
    if(deadline.status!==0){this.onRejectedEvent({targetId,event,now,delta,status:deadline.status});return null;}
    const record=this.record(targetId,event,deadline);insertTimedEvent(this.events,record,clock.dayLength,delta.time!==0);return record;
  }
  enqueueAbsolute(targetId,event,day,time,fromTail=false){
    const clock=this.clock(),record=this.record(targetId,event,{day,time});insertTimedEvent(this.events,record,clock.dayLength,Boolean(fromTail));return record;
  }
  isDue(record,now=this.worldTime()){return timedEventDue(record,now,this.clock().dayLength);}
  takeEvent(){return this.events.shift();}
  advance(milliseconds){if(Number.isFinite(milliseconds)&&milliseconds>=0)this.time+=milliseconds;}
  async pump(){
    if(this.pumping)return;this.pumping=true;
    try{
      if(await this.beforePump()===true)return;
      const now=this.worldTime();let count=0;
      while(this.isDue(this.events[0],now)&&count++<this.maxEventsPerPump){
        const queued=this.takeEvent();if(!this.validTarget(queued.targetId))continue;
        try{await this.dispatch(queued);}catch(error){this.onError(error,queued);}
      }
      // Diagnostic pump only: overflow remains queued. Normal native AI owns
      // its complete interleaved event/budget traversal.
    }finally{this.pumping=false;}
  }
}
