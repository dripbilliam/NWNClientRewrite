// CNWCAmbientSound875ad0..878711, target EE89.8193.37-17. This owner
// controls presentation streams only. It neither allocates canonical objects
// nor runs a module script, spell resolver or authoritative world clock.
const defaults={'8':1,'c':5000,'10':2,'14':3,'18':0,'1c':1,'20':1,'24':1,'28':2,'2c':0,'2d':0};
const equal=(a,b)=>String(a??'').toLowerCase()===String(b??'').toLowerCase();
export class NativeAmbientOwner{
 constructor({state={},resolve,streams,stinger=()=>{},random=()=>Math.floor(Math.random()*0x8000),singleStream=false,specialTracks=['','']}){
  Object.assign(this,{resolve,streams,stinger,random,singleStream,specialTracks});this.s={...defaults,...state};this.tracks={};
  this.enabled=false;this.musicEnabled=true;this.ambientEnabled=true;this.day=true;this.mode=0;this.category=0;this.retry=0;this.ambientFailed=0;this.longFade=false;this.lastTime=null;
  this.delay=state.c===undefined?30000:state.c||1;
  for(const [key,music]of [['10',true],['14',true],['1c',true],['24',false],['28',false]])this.loadTrack(key,music,this.s[key]);
 }
 loadTrack(key,music,id){const value=this.resolve(music,id);this.tracks[key]={resource:value?.resource??'',stingers:value?.stingers??[]};if(!music&&value?.resource)this.ambientFailed=0;}
 track(key){return this.tracks[key]?.resource??'';}
 play(stream,key,type){return this.streams[stream].play(this.track(key),type);}
 scheduleFailure(ok){if(!ok)this.retry=10000;}
 sharedPlay(){
  if(this.s['18']){this.scheduleFailure(this.play('music','1c',8));this.category=4;}
  else if(this.s['20']){if(this.mode===1||this.mode===2){this.scheduleFailure(this.streams.music.play(this.specialTracks[this.mode-1],4));this.category=3;}else{this.scheduleFailure(this.play('music',this.day?'24':'28',4));this.category=2;}}
  else if(this.s['8']){this.scheduleFailure(this.play('music',this.day?'10':'14',8));this.category=1;}
  else{this.retry=10000;this.category=0;}
 }
 music(play){
  if(!this.enabled)return;
  if(this.singleStream){this.s['8']=Number(Boolean(play));this.retry=10;if(!this.streams.music.isPlaying()){if(play)this.sharedPlay();}else if(this.category<1&&play||this.category===1&&!play)this.streams.music.fadeAndStop(1000);return;}
  if(!play){this.streams.music.fadeAndStop(this.longFade?10000:800);this.s['8']=0;return;}
  if(this.musicEnabled){if(!this.streams.music.isPlaying()){this.retry=0;this.scheduleFailure(this.play('music',this.day?'10':'14',8));}this.s['8']=1;}
 }
 ambient(play){
  if(!this.enabled)return;
  if(this.singleStream){this.s['20']=Number(Boolean(play));this.retry=10;if(!this.streams.music.isPlaying()){if(play)this.sharedPlay();}else if(this.category<2&&play||this.category===2&&!play)this.streams.music.fadeAndStop(1000);return;}
  if(!play){this.streams.ambient.fadeAndStop(6000);this.s['20']=0;this.ambientFailed=0;return;}
  if(this.ambientEnabled){if(!this.streams.ambient.isPlaying()){
   const special=this.mode===1||this.mode===2,key=this.day?'24':'28';this.streams.ambient.setVolume(this.s[special||this.day?'2c':'2d']);
   this.ambientFailed=Number(!this.streams.ambient.play(special?this.specialTracks[this.mode-1]:this.track(key),4));
  }this.s['20']=1;}
 }
 playStinger(){if(!this.enabled)return;const tracks=this.tracks['1c'].stingers;if(!tracks[0])return;let count=1;if(tracks[1]){count=2;if(tracks[2])count=3;}this.stinger(tracks[this.random()%count]);}
 battle(play){
  const stream=this.streams.music;
  if(this.singleStream){this.s['18']=Number(Boolean(play));this.retry=10;if(!stream.isPlaying()){if(play)this.sharedPlay();}else if(this.category<4&&play)stream.fadeAndStop(1000);else if(this.category===4&&!play){stream.fadeAndStop(1000);this.playStinger();}return;}
  if(!play){if(this.s['18']){stream.fadeAndStop(800);if(this.musicEnabled){this.playStinger();this.music(1);}this.s['18']=0;}return;}
  if(this.musicEnabled&&this.enabled&&this.track('1c')){this.s['18']=1;if(!stream.isPlaying()){this.retry=0;this.scheduleFailure(this.play('music','1c',8));}else if(!equal(stream.file(),this.track('1c'))){stream.fadeAndStop(800);this.s['8']=0;this.retry=10;this.captureClock?.();}}
 }
 start(){this.enabled=true;if(this.musicEnabled){if(this.s['18'])this.battle(1);else this.music(this.s['8']);}if(this.ambientEnabled)this.ambient(this.s['20']);}
 command(message){
  const {operation:op,day,value,play}=message;
  if(op===1)this.music(play);
  else if(op===2){if(value>0)this.delay=value;}
  else if(op===4)this.battle(play);
  else if(op===6)this.ambient(play);
  else if(op===3||op===7||op===5){
   const music=op!==7,key=op===5?'1c':music?(day?'10':'14'):(day?'24':'28'),stream=this.streams[music?'music':'ambient'];
   const matching=equal(stream.file(),this.track(key)),stop=stream.isPlaying()&&matching;
   if(op===5){if(stop)this.battle(0);this.loadTrack(key,true,value);this.s[key]=value;if(stop)this.battle(1);}
   else{if(stop)(music?this.music(0):this.ambient(0));this.loadTrack(key,music,value);this.s[key]=value;if(music){this.music(1);this.retry=1;}else this.ambient(1);}
  }else if(op===8){const key=day?'2c':'2d',track=day?'24':'28';if(this.s[key]!==value){const stream=this.streams.ambient;if(stream.isPlaying()&&equal(stream.file(),this.track(track)))stream.setVolume(value&255);this.s[key]=value&255;}}
  else throw new Error('Unsupported native ambient command');
 }
 dayNight(timeOfDay){
  const day=timeOfDay<2||timeOfDay===3;if(!day&&timeOfDay!==2&&timeOfDay!==4)return;if(day===this.day)return;
  const music=this.streams.music,ambient=this.streams.ambient,oldMusic=this.day?'10':'14',oldAmbient=this.day?'24':'28';
  if(equal(music.file(),this.track(oldMusic))||this.singleStream&&equal(music.file(),this.track(oldAmbient))){this.longFade=true;this.music(0);this.retry=10;this.music(1);this.longFade=false;}
  if(equal(ambient.file(),this.track(oldAmbient))){this.ambient(0);this.ambient(1);}this.day=day;
 }
 // Caller supplies elapsed native world milliseconds. Audio-device loading is
 // deliberately not awaited by the network pump or frame coordinator.
 frame(now){
  if(!this.streams.music.isPlaying()){
   if(!this.retry){if(this.s['8']||this.s['18']){this.retry=this.singleStream?10:this.s['18']?1000:this.delay||1;this.lastTime=now;}}
   else{const elapsed=this.lastTime===null?0:Math.max(0,now-this.lastTime);if(this.retry<=elapsed){this.retry=0;if(this.singleStream)this.sharedPlay();else if(this.s['18'])this.battle(1);else this.music(1);}else{this.retry-=elapsed;this.lastTime=now;}}
  }
  if(!this.singleStream&&!this.streams.ambient.isPlaying()&&this.s['20']&&!this.ambientFailed)this.ambient(1);
 }
 snapshot(){return{fields:{...this.s},delay:this.delay,retry:this.retry,ambientFailed:this.ambientFailed,enabled:this.enabled,day:this.day,category:this.category,singleStream:this.singleStream,tracks:structuredClone(this.tracks)};}
 dispose(){for(const s of Object.values(this.streams))s.dispose();this.enabled=false;}
}
