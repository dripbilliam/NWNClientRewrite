import { NativeIdList } from './native_id_list.js';
import { subtractWorldTimes } from './reputation.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native module AI ${name} is unavailable`);return value;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native module AI provider ${name} is unavailable`);return p[name];};
const elapsed=(now,owner,dayField,timeField,p)=>{
  const result=subtractWorldTimes(now,{day:integer(owner[dayField],dayField),time:integer(owner[timeField],timeField)},p.dayLength);
  // These callers leave the subtraction outputs uninitialized on failure.
  // Do not replace a backwards/undefined native elapsed value with zero.
  if(result.status!==0)throw new Error('Native module AI elapsed time is undefined after failed subtraction');
  return result.milliseconds;
};

// CNWSModule::LoadModuleStart140480d2f..140480da0 and UpdateTime14048a330.
export function moduleTimeOfDay(hour,dawn,dusk){
  hour=integer(hour,'hour')>>>0;dawn=integer(dawn,'dawn')&255;dusk=integer(dusk,'dusk')&255;
  if(dawn===dusk)return 1;
  if(hour===dawn)return 3;
  if(hour===dusk)return 4;
  return dawn<dusk?(hour<dawn||hour>dusk?2:1):(hour>=dusk&&hour<=dawn?2:1);
}

export function initializeModuleAI(module,ifo,timer){
  module.nativeLastPCRested380??=0x7f000000;module.nativeLastRestEvent384??=0; // ctor14047865b/665.
  module.nativeAreaIds50??=new NativeIdList();module.nativeAreaUpdateIndex60??=-1;
  module.nativeHeartbeatDay318??=0;module.nativeHeartbeatTime31c??=0;
  module.nativeDawnHour3b9=(ifo.Mod_DawnHour??0)&255;module.nativeDuskHour3ba=(ifo.Mod_DuskHour??0)&255;
  // Native load caches authored fields BEFORE SetCalendar normalizes them.
  module.nativeCalendarYear3c0=(ifo.Mod_StartYear??1340)>>>0;
  module.nativeCalendarMonth3c4=(ifo.Mod_StartMonth??6)&255;
  module.nativeCalendarDay3c8=(ifo.Mod_StartDay??1)&255;
  module.nativeCalendarHour3cc=(ifo.Mod_StartHour??23)&255;
  module.nativeTimeTransition3d0=(ifo.Mod_Transition??0)>>>0;
  module.nativeTimeOfDay3d4=moduleTimeOfDay(module.nativeCalendarHour3cc,module.nativeDawnHour3b9,module.nativeDuskHour3ba);
  const now=timer.time();module.nativeCalendarDay3d8=now.day;module.nativeCalendarTime3dc=now.time;
}

export function initializeAreaAI(area,are,timer){
  area.nativeHeartbeatDay16c??=0;area.nativeHeartbeatTime170??=0;
  area.nativeChanceRainE1=(are.ChanceRain??0)&255;area.nativeChanceSnowE2=(are.ChanceSnow??0)&255;
  if((integer(area.flags,'area flags')&1)!==0){area.nativeChanceRainE1=0;area.nativeChanceSnowE2=0;}
  area.nativeWeatherType330??=0;area.nativeWeatherOn334??=0;area.nativeWeatherTimer338??=0;
  const now=timer.time();area.nativeWeatherDay33c??=now.day;area.nativeWeatherTime340??=now.time;
  area.nativeWeatherOverride344??=255;area.nativeWeatherCached345??=0;
}

export async function updateModuleTime(module,now,milliseconds,p){
  const date=required(p,'calendar')(now.day),time=required(p,'timeParts')(now.time);
  const timeOfDay=moduleTimeOfDay(time.hour,module.nativeDawnHour3b9,module.nativeDuskHour3ba);
  const previous=integer(module.nativeTimeOfDay3d4,'previous time of day')&255;
  module.nativeTimeTransition3d0=previous===3||previous===4?
    ((integer(module.nativeTimeTransition3d0,'transition elapsed')>>>0)+(milliseconds>>>0))>>>0:0;
  let mask=0;
  for(const [field,value,bit] of [['nativeTimeOfDay3d4',timeOfDay,1],['nativeCalendarHour3cc',time.hour,2],
    ['nativeCalendarDay3c8',date.day,4],['nativeCalendarMonth3c4',date.month,8],['nativeCalendarYear3c0',date.year,16]]){
    integer(value,field);if(integer(module[field],field)!==value){module[field]=value;mask|=bit;}
  }
  if(mask!==0)for(const client of required(p,'clients')())await required(p,'sendTime')(client,{mask,...date,hour:time.hour,timeOfDay,transition:module.nativeTimeTransition3d0});
  return mask;
}

export async function updateModuleAI(module,p){
  const now=required(p,'worldTime')();let result=0;
  if(elapsed(now,module,'nativeHeartbeatDay318','nativeHeartbeatTime31c',p)>=6000){
    if(module.nativeHeartbeatTime31c!==0&&module.scripts?.heartbeat)await required(p,'runHeartbeat')(module);
    module.nativeHeartbeatDay318=now.day;module.nativeHeartbeatTime31c=now.time;result=1;
  }
  await updateModuleTime(module,now,elapsed(now,module,'nativeCalendarDay3d8','nativeCalendarTime3dc',p),p);
  module.nativeCalendarDay3d8=now.day;module.nativeCalendarTime3dc=now.time;
  if((integer(required(p,'activePauseState')(),'pause state')&255)===1){
    let keep=0;
    for(const id of required(p,'exclusionIds')()){
      const actor=required(p,'creature')(id>>>0);if(!actor)continue;
      // ModuleAIUpdate14047a610: native effect WORD+8 constant140de7b9c=64.
      for(const effect of required(p,'effects')(actor))if((integer(effect.type,'effect type')&65535)===64)keep=1;
    }
    if(keep===0)await required(p,'togglePause')(1);
  }
  return result;
}

export async function updateAreaAI(area,p){
  const now=required(p,'worldTime')();
  const milliseconds=elapsed(now,area,'nativeWeatherDay33c','nativeWeatherTime340',p);
  area.nativeWeatherDay33c=now.day;area.nativeWeatherTime340=now.time;
  if((integer(area.nativeWeatherOverride344,'weather override')&255)===255&&(integer(area.flags,'area flags')&1)===0){
    const timer=integer(area.nativeWeatherTimer338,'weather timer')>>>0;
    if(timer!==0)area.nativeWeatherTimer338=milliseconds<timer?(timer-milliseconds)>>>0:0;
    else{
      // Even a dry outdoor area consumes one shared CRT rand when timer==0.
      const roll=integer(required(p,'random')(),'weather random')%100;
      const rain=integer(area.nativeChanceRainE1,'rain chance')&255,snow=integer(area.nativeChanceSnowE2,'snow chance')&255;
      const kind=rain!==0?1:snow!==0?2:0,chance=rain!==0?rain:snow;
      if(kind!==0){
        const on=integer(area.nativeWeatherOn334,'weather on'),change=roll<chance?on===0:on!==0;
        if(change){
          const next=roll<chance?1:0;area.nativeWeatherType330=kind;area.nativeWeatherOn334=next;
          for(const client of required(p,'clients')()){
            const object=required(p,'clientObject')(client);
            if(object&&required(p,'area')(object)!==null){
              const current=required(p,'area')(object);if(current&&current.id===area.id)await required(p,'sendWeather')(client,{areaId:area.id,kind,on:next});
            }
          }
          area.nativeWeatherCached345=next!==0?kind:0;
        }
      }
      area.nativeWeatherTimer338=300000;
    }
  }
  if(elapsed(now,area,'nativeHeartbeatDay16c','nativeHeartbeatTime170',p)<6000)return 0;
  if(area.nativeHeartbeatTime170!==0&&area.scripts?.heartbeat)await required(p,'runHeartbeat')(area);
  area.nativeHeartbeatDay16c=now.day;area.nativeHeartbeatTime170=now.time;return 1;
}

// DoUpdate14047bea0: first update visits module (constructor index=-1),
// then one canonical IFO area per call, then module again. Reload index after
// the area callback, since scripts can mutate the owner's array/index.
export async function updateModule(module,p){
  const index=integer(module.nativeAreaUpdateIndex60,'area update index')|0,list=module.nativeAreaIds50;
  if(!(list instanceof NativeIdList))throw new Error('Native module area ID list is unavailable');
  if(index<list.count&&index!==-1){
    if(index<0)throw new Error('Native module area update index is undefined');
    const area=required(p,'areaById')(list.ids[index]>>>0);
    if(area)await updateAreaAI(area,p);
    module.nativeAreaUpdateIndex60=(integer(module.nativeAreaUpdateIndex60,'area update index')+1)|0;
  }else{module.nativeAreaUpdateIndex60=0;await updateModuleAI(module,p);}
}
