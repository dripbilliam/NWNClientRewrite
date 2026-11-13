import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {WorldTimer,addWorldTimes,compareWorldTimes,subtractWorldTimes} from '../../src/world_timer.js';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const expected={
 'native-client-pause-observations.json':'5f1827c3f528b9f40a698fbd7a3287f15969cf2fd74f87f58b124fca6593b8b1',
 'native-client-creature-clock-observations.json':'9dd68ce3a17082f316ae1e697f410a28dc449baf463546e8fae9e2c14f6300eb',
 'native-seconds-world-delta-observations.json':'f8014d38f18c76fe946ddc12c75123871ba1131b5b834ee1e11d65bf9e31be34'
};
const words=value=>({hi:Number(BigInt.asUintN(64,BigInt(value))>>32n),lo:Number(BigInt.asUintN(32,BigInt(value)))});
const fields=['mode','fixedRate','counter','previousCounter','paused','pausedDay','pausedTime','dayOffset','timeOffset','minutesPerHour','dayLength','secondsPerDay'];
const timerState=timer=>({ready:true,...Object.fromEntries(fields.map(key=>[key,['counter','previousCounter'].includes(key)?words(timer[key]):timer[key]??null]))});
function corpus(name){const bytes=fs.readFileSync(path.join(workspace,'backups/animations',name));if(digest(bytes)!==expected[name])throw Error('Original corpus hash differs: '+name);const data=JSON.parse(bytes);if(data.binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original target differs');return data;}
export function remoteClientClockFixture(){
 const pause=corpus('native-client-pause-observations.json'),creature=corpus('native-client-creature-clock-observations.json'),seconds=corpus('native-seconds-world-delta-observations.json');
 if(pause.rows.length!==759||creature.rows.length!==90||seconds.rows.length!==55)throw Error('Original corpus counts differ');
 const pauseRows=pause.rows.map(row=>({...row,timers:Object.fromEntries(Object.entries(row.timers).map(([key,value])=>[key,{...value,counter:words(value.counter),previousCounter:words(value.previousCounter)}]))}));
 const timerCases=[];
 function make(label,epoch,actions){
  let micro=BigInt(epoch);const timer=new WorldTimer(()=>micro),initial=timerState(timer),steps=[];
  for(const action of actions){let result=null;
   if(action.kind==='provider')micro=BigInt(action.value);
   else if(action.kind==='snapshot')timer.snapshot();
   else if(action.kind==='setTime')timer.setTime(action.day,action.time,action.snapshot??0);
   else if(action.kind==='minutes')timer.setMinutesPerHour(action.value);
   else if(action.kind==='pause')timer.pause();
   else if(action.kind==='unpause')timer.unpause();
   else if(action.kind==='mode'){timer.mode=action.value;timer.fixedRate=action.fixedRate;}
   else if(action.kind==='calendar')timer.setCalendar(...action.args);
   else if(action.kind==='readCalendar')result=timer.calendar(action.value);
   else if(action.kind==='readParts')result=timer.timeParts(action.value);
   else throw Error('Unknown fixture action');
   const difference=BigInt.asUintN(64,timer.counter-timer.previousCounter);
   const frameSeconds=Math.fround(Math.fround(Number(BigInt.asIntN(32,difference)))/1000000),floatBytes=Buffer.alloc(4);floatBytes.writeFloatLE(frameSeconds);
   steps.push({action,result,time:timer.time(),state:timerState(timer),difference:words(difference),frameSeconds,frameSecondsBits:floatBytes.readUInt32LE()});
  }
  timerCases.push({label,epoch:String(epoch),constructorProviderRepresentable:BigInt(epoch)<=0x7fffffffffffffffn,initial,time:new WorldTimer(()=>BigInt(epoch)).time(),steps});
 }
 for(const epoch of [0n,1001n,123456789012345n,0xffffffffffffffffn])make('epoch-'+epoch,epoch,[{kind:'setTime',day:7,time:7199999},{kind:'mode',value:1,fixedRate:30},{kind:'snapshot'},{kind:'snapshot'},{kind:'pause'},{kind:'snapshot'},{kind:'unpause'}]);
 make('absolute-integer-millisecond',123456789n,[{kind:'setTime',day:7,time:7199999},{kind:'provider',value:'123457789'},{kind:'snapshot'},{kind:'provider',value:'123457999'},{kind:'snapshot'},{kind:'provider',value:'123458000'},{kind:'snapshot'}]);
 make('pause-unpause',0n,[{kind:'setTime',day:100,time:1},{kind:'pause'},{kind:'provider',value:'10000000'},{kind:'snapshot'},{kind:'pause'},{kind:'unpause'},{kind:'provider',value:'10001000'},{kind:'snapshot'},{kind:'unpause'}]);
 make('signed-fixed-rate-wrap',0n,[{kind:'mode',value:1,fixedRate:-1},{kind:'snapshot'},{kind:'snapshot'},{kind:'setTime',day:0xffffffff,time:0xffffffff}]);
 make('calendar-native-fallback',0n,[{kind:'minutes',value:1},{kind:'calendar',args:[32001,0,0,24,60,60,1440000]},{kind:'calendar',args:[32000,12,28,23,59,59,999]},{kind:'readCalendar',value:0xffffffff},{kind:'minutes',value:5},{kind:'readParts',value:1859999},{kind:'minutes',value:256}]);
 const arithmetic=[];
 for(const length of [1,1000,7200000,0x80000010,0xffffffff])for(const values of [
  [0,0,0,0],[0xffffffff,length-1,1,length-1],[5,0,4,length-1],[0,0,1,0],[0xffffffff,0xffffffff,0,1],[7,-1,-1,0],[0,0xffffffff,0,0xffffffff]
 ]){
  const [day,time,otherDay,otherTime]=values,a={day,time},b={day:otherDay,time:otherTime};
  arithmetic.push({length,a,b,add:addWorldTimes(a,b,length),compare:compareWorldTimes(a,b,length),subtract:subtractWorldTimes(a,b,length)});
 }
 // Separate authored full-DWORD edge oracle: execute the literal source
 // loops, not the candidate's O(1) normalization. No original corpus changes.
 const normalization=[],seen=new Set();let totalIterations=0,maximumIterations=0;
 function literalNormalization(day,time,length){let underflowIterations=0,carryIterations=0;
  while(time>((~length)>>>0)){if(++underflowIterations>65536)throw Error('Bounded literal underflow case exceeds65536');day=(day-1)>>>0;time=(time+length)>>>0;}
  while(time>=length){if(++carryIterations>65536)throw Error('Bounded literal carry case exceeds65536');day=(day+1)>>>0;time=(time-length)>>>0;}
  return{day,time,underflowIterations,carryIterations};
 }
 function emit(label,day,time,length){const key=[day,time,length].join(':');if(seen.has(key))return;seen.add(key);const result=literalNormalization(day>>>0,time>>>0,length>>>0);normalization.push({label,day:day>>>0,time:time>>>0,length:length>>>0,result});const count=result.underflowIterations+result.carryIterations;totalIterations+=count;maximumIterations=Math.max(maximumIterations,count);}
 emit('reported-FFFFFFFF-two-underflows',10,2,0xffffffff);
 for(const length of [1,2,1000,1440000,7200000,367200000,0x7fffffff,0x80000000,0x80000001,0xc0000000,0xffffff00,0xfffffffe,0xffffffff])for(const time of [0,1,2,15,1024,4096])emit('target-'+length+'-'+time,10,time,length);
 for(const length of [0x7fffffff,0x80000000,0x80000001,0xc0000000,0xffff0000])emit('full-DWORD-time-'+length,0xffffffff,0xffffffff,length);
 emit('day-wrap-underflow',0,7,0xfffffffe);
 let seed=0x7242f00d;const next=()=>seed=(Math.imul(seed,1664525)+1013904223)>>>0;
 for(let i=0;i<256;i++){const day=next();let length,time;
  if(i%3===0){length=(0xffffffff-(next()%4096))>>>0;time=next()%8193;}
  else if(i%3===1){length=(0x80000000+(next()>>>1))>>>0;time=next();}
  else{length=1+next()%14400000;time=next()%Math.min(0x100000000,length*4096);}
  emit('seeded-'+i,day,time,length);
 }
 return {version:1,sourcePins:Object.entries(expected).map(([name,sha256])=>({path:'backups/animations/'+name,sha256})),binarySha256:pause.binarySha256,
  provenance:{originalPauseCases:759,originalCreatureCases:90,originalSecondsCases:55,pauseTimerCallbacksCaptured:true,realGuiAudioObjects:false,timerReference:'src/world_timer.js',timerReferenceIsOriginalExecution:false,remoteInitializationInferred:false},
  pause:pauseRows,creature:creature.rows,seconds:seconds.rows,timerCases,arithmetic,
  normalization:{provenance:'Authored literal GetWorldTime597180 DWORD loops; not new original execution and separate from all904 retained native cases',seed:'0x7242f00d',rows:normalization,totalIterations,maximumIterations,iterationBound:65536}};
}

