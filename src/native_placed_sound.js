import {nativeAudioResRef} from './native_audio.js';
const f=Math.fround;
export function nativeSoundInterval(base,variation,random){
 base|=0;variation|=0;if(!base)return null;if(!variation)return base>>>0;
 const divisor=Math.imul(variation,2)>>>0;if(!divisor)throw new Error('Native sound interval variation divides by zero');
 const value=(base-variation+(random()>>>0)%divisor)|0;return value<1?0:value>>>0;
}
export function nativeSoundPitchRate(sampleRate,variation,random){
 variation=f(variation);if(!variation)return 1;const add=(random()&1)!==0,span=Math.trunc(add?f(f(sampleRate)*variation):f(f(f(sampleRate)*f(.5))*variation))>>>0;
 const rate=span?(sampleRate+(add?1:-1)*((random()>>>0)%span))>>>0:sampleRate;
 if(!rate||!sampleRate)throw new Error('Native sound pitch sample rate is unavailable');return rate/sampleRate;
}
// Client area tile lookup7db200 uses inclusive edges and the first match.
export function nativeSoundTileIndex(position,width,height){const axis=(v,n)=>{for(let i=0;i<n;i++)if(f(i*10)<=v&&v<=f((i+1)*10))return i;return-1;},x=axis(f(position[0]),width),y=axis(f(position[1]),height);return x<0||y<0?-1:x+width*y;}

// CNWCSoundObject989610 frame,98a260 selection,98ad10 interval and98af90
// time gate. Device/resource IO is supplied by a presentation-only source.
export class NativePlacedSound{
 constructor({sound,source,area,random=()=>Math.floor(Math.random()*0x8000),now=0}){
  Object.assign(this,{source,area,random});const s=sound.fields;this.id=sound.id;this.refs=sound.refs.map(nativeAudioResRef);this.position=sound.position.map(f);this.height=this.position[2];
  this.active=s['308'];this.positional=s['30c'];this.looping=s['310'];this.volume=s['314'];this.volumeVariation=s['318'];this.times=s['31c'];this.pitchVariation=s['320'];this.hours=s['324'];this.interval=s['348'];this.intervalVariation=s['34c'];this.continuous=s['358'];this.randomList=s['35c'];this.randomPosition=s['32c'];this.ranges=[s['330'],s['334']].map(f);
  this.priority=this.looping?(this.positional?3:2):(this.positional?20:19);
  if(this.continuous&&this.refs.length===1&&!this.randomPosition&&!this.interval)this.looping=1;
  this.allowed=1;this.first=true;this.index=0;this.remaining=0;this.gap=nativeSoundInterval(this.interval,this.intervalVariation,this.random)??0;this.lastTime=Math.trunc(now);this.loopPending=Boolean(this.looping&&this.active);this.pending=null;
  source.configure({positional:Boolean(this.positional),loop:Boolean(this.looping),priority:this.priority,referenceDistance:s['350'],maxDistance:s['354']});source.setPosition(this.position);
 }
 timeGate({hour,timeOfDay}){if(this.times===0){this.allowed=Number(Boolean((this.hours>>>0)&(1<<(hour&31))));return;}if(timeOfDay<2||timeOfDay===3)this.allowed=Number(this.times!==2);else if(timeOfDay===2||timeOfDay===4)this.allowed=Number(this.times!==1);}
 select(){
  if(!this.refs.length)return'0';
  if(!this.first){if(this.index<this.refs.length-1)return this.refs[++this.index];if(!this.continuous)return'0';if(this.randomList){const old=[...this.refs],next=[];while(old.length)next.push(old.splice(this.random()%old.length,1)[0]);this.refs=next;}}
  else this.first=false;
  this.index=0;return this.refs[0];
 }
 play(now){if(!this.source.hardwarePlaying()){this.gap=0;this.remaining=0;this.first=true;this.lastTime=Math.trunc(now);this.pending=null;}if(this.active!==1){this.gap=0;this.active=1;if(this.looping)this.loopPending=true;}}
 stop(){this.active=0;this.gap=0;this.remaining=0;this.pending=null;this.source.stop();}
 setVolume(value){this.volume=value|0;this.source.setVolume(value&255);}
 move(position){this.position=position.map(f);this.source.setPosition(this.position);}
 varyPosition(){
  const point=[0,0,this.position[2]];
  for(let i=0;i<2;i++){
   const maximum=f(f(i===0?this.area.width:this.area.height)*10),range=this.ranges[i],lo=range===0?0:Math.max(0,f(this.position[i]-range)),span=range===0?maximum:f(Math.min(maximum,f(this.position[i]+range))-lo);
   point[i]=f(lo);if(span>0){const divisor=Math.trunc(f(span*100));if(divisor<=0)throw new Error('Native sound random-position range divides by zero');point[i]=f(point[i]+f((this.random()%divisor)/100));}
  }
  const height=this.area.tileHeightAt(point);if(!Number.isInteger(height))throw new Error('Native sound random position has no tile');point[2]=f(f(height)+this.height);this.position=point;this.source.setPosition(point);
 }
 finish(duration,loop){
  this.remaining=duration>>>0;
  if(loop){if(!duration){this.active=0;this.gap=0;}return;}
  if(!duration){if(this.refs.length<2){this.active=0;this.gap=0;return;}this.refs.splice(this.index,1);if(this.index>0)this.index--;}
  if(this.continuous||this.index<this.refs.length-1)this.gap=nativeSoundInterval(this.interval,this.intervalVariation,this.random)??this.gap;
 }
 frame(now,time){
  now=Math.trunc(now);
  if(this.times===0)this.timeGate(time);
  if(!this.active){if(this.source.hardwarePlaying())this.source.stop();return;}
  if(!this.allowed){if(this.source.hardwarePlaying()){this.source.stop();if(this.looping)this.loopPending=true;}return;}
  if(this.pending){const duration=this.source.play();if(duration===null)return;const {loop}=this.pending;this.pending=null;this.finish(duration,loop);return;}
  if(this.looping){
   if(!this.loopPending)return;this.loopPending=false;this.first=true;this.source.setResRef(this.select());this.source.setVolume(this.volume&255);const duration=this.source.play();if(duration===null)this.pending={loop:true};else this.finish(duration,true);return;
  }
  let elapsed=Math.max(0,now-this.lastTime)>>>0;this.lastTime=now;
  if(this.remaining){if(elapsed<this.remaining){this.remaining-=elapsed;return;}this.remaining=0;elapsed=0;}
  if(this.gap){if(elapsed<this.gap){this.gap-=elapsed;return;}this.gap=0;}
  const ref=this.select();if(ref==='0'){this.active=0;this.gap=0;return;}
  this.source.setResRef(ref);this.source.setVolume(this.volume&255);
  if(this.volumeVariation>0){const value=((this.random()%(this.volumeVariation*2)-this.volumeVariation)+this.volume)|0;this.source.setVolume(Math.max(0,Math.min(127,value)));}
  if(this.randomPosition)this.varyPosition();this.source.setPitchVariance(this.pitchVariation);
  const duration=this.source.play();if(duration===null)this.pending={loop:false};else this.finish(duration,false);
 }
 snapshot(){return{id:this.id,active:this.active,allowed:this.allowed,looping:this.looping,priority:this.priority,index:this.index,refs:[...this.refs],position:[...this.position],remaining:this.remaining,gap:this.gap,pending:Boolean(this.pending),source:this.source.snapshot?.()};}
 dispose(){this.source.dispose();this.active=0;this.pending=null;}
}
