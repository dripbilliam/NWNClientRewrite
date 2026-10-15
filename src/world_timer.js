const u32=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native world ${name} is unavailable`);return value>>>0;};
const u64=value=>BigInt.asUintN(64,BigInt(value));
// CWorldTimer 140596aa0; GetWorldTime 140597180..140597223;
// SetWorldTime 1405978d0 / 140597970; SetSnapshotTime 140597880.
// Clock ticks come from an explicit monotonic provider; epoch is local to the
// session, not native process uptime. Stored offsets cancel that epoch.
export class WorldTimer{
  constructor(microseconds){
    if(typeof microseconds!=='function')throw new Error('Native world timer source is unavailable');
    this.microseconds=microseconds;this.counter=u64(microseconds());this.previousCounter=this.counter;
    this.mode=0;this.paused=0;this.minutesPerHour=5;this.dayLength=7200000;this.secondsPerDay=7200;
    this.setTime(0x6df4c,5*0x150ea0+0x36dee0);
  }
  snapshot(){
    this.previousCounter=this.counter;
    if(this.mode===0)this.counter=u64(this.microseconds());
    else{
      const rate=this.fixedRate|0;if(!rate)throw new Error('Native fixed world timer divides by zero');
      this.counter=u64(this.counter+BigInt(Math.trunc(1000000/rate)));
    }
  }
  setMinutesPerHour(value){
    this.minutesPerHour=(u32(value,'minutes per hour')&255)||1;
    this.dayLength=this.minutesPerHour*1440000;this.secondsPerDay=this.minutesPerHour*1440;
  }
  setTime(day,time,snapshot=0){
    day=u32(day,'day');time=u32(time,'time');
    if(snapshot===1)this.snapshot();
    const elapsed=this.counter/1000n,length=BigInt(this.dayLength);
    this.dayOffset=(day-Number(elapsed/length&0xffffffffn))>>>0;
    this.timeOffset=(time-Number(elapsed%length))>>>0;
  }
  time(){
    if(this.paused===1)return{day:this.pausedDay,time:this.pausedTime};
    const length=u32(this.dayLength,'day length');if(length===0)throw new Error('Native world day length divides by zero');
    const elapsed=this.counter/1000n;
    let day=(Number(elapsed/BigInt(length)&0xffffffffn)+this.dayOffset)>>>0;
    let time=(Number(elapsed%BigInt(length))+this.timeOffset)>>>0;
    // Native handles subtraction wrap first, then carries positive days.
    while(time>((~length)>>>0)){day=(day-1)>>>0;time=(time+length)>>>0;}
    while(time>=length){day=(day+1)>>>0;time=(time-length)>>>0;}
    return{day,time};
  }
  // CWorldTimer calendar/time conversions140596e90/140596ee0. Calendar
  // months are28 days; an out-of-range converted year falls back to1340.
  calendar(day=this.time().day){
    day=u32(day,'calendar day');const months=Math.floor(day/28),year=Math.floor(months/12);
    return{year:year>32767?1340:year,month:months%12+1,day:day%28+1};
  }
  timeParts(time=this.time().time){
    time=u32(time,'calendar time');const rate=u32(this.minutesPerHour,'minutes per hour')&255;
    if(rate===0)throw new Error('Native calendar conversion divides by zero');
    const seconds=Math.floor(time/1000),minutes=Math.floor(seconds/60);
    return{hour:Math.floor(minutes/rate),minute:minutes%rate,second:seconds%60,millisecond:time%1000};
  }
  // Native getters140597390/140597480/140597540 read current world time,
  // including its pause and offset normalization, rather than module caches.
  getHour(){return this.timeParts().hour;}
  getMinute(){return this.timeParts().minute;}
  getSecond(){return Math.floor(this.time().time/1000)%60;}
  setCalendar(year,month,day,hour,minute,second,millisecond,snapshot=0){
    [year,month,day,hour,minute,second,millisecond]=[year,month,day,hour,minute,second,millisecond].map(v=>u32(v,'calendar argument'));
    let date=year<32001?Math.imul(year,336):0x6dec0;
    date=(date+(((month-1)>>>0)<12?Math.imul(month,28)-28:140))>>>0;
    if(((day-1)>>>0)<28)date=(date+day-1)>>>0;
    const time=(Math.imul(this.minutesPerHour,hour<24?Math.imul(hour,60000):1380000)+
      (minute<60?Math.imul(minute,60000):3540000)+(second<60?Math.imul(second,1000):56000)+millisecond)>>>0;
    this.setTime(date,time,snapshot);
  }
  // Module load 140480a61..140480ca8, byte/ushort field reads and
  // missing-field defaults from 140e02d08/18/24/30. New-game initialization;
  // saved module clocks and area-specific timers remain separate lifecycle.
  loadModule(ifo){
    this.setMinutesPerHour((ifo.Mod_MinPerHour??0)&255);
    this.setCalendar(ifo.Mod_StartYear??1340,(ifo.Mod_StartMonth??6)&255,(ifo.Mod_StartDay??1)&255,
      (ifo.Mod_StartHour??23)&255,(ifo.Mod_StartMinute??0)&65535,(ifo.Mod_StartSecond??0)&65535,
      (ifo.Mod_StartMiliSec??0)&65535,1);
  }
  pause(){if(this.paused===0){const now=this.time();this.pausedDay=now.day;this.pausedTime=now.time;this.paused=1;}}
  unpause(){if(this.paused===1){this.paused=0;this.setTime(this.pausedDay,this.pausedTime);}}
}
