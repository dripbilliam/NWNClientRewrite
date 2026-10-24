// Decoded native area state only; Godot owns interpolation and fog per frame.
// Nothing here queries a server, advances game time, or invents area lighting.
const offsets=['98','9c','a0','a4','a8','ac','b0','b4','b8','bc','c0','c4','c8','cc','d0','d4','d8','dc','e0','104','108'];
export class EnvironmentDelivery {
 constructor({session,connection,active,ready,send,sky,weather,now=()=>performance.now()}){Object.assign(this,{session,connection,active,ready,send,sky,weather,now});this.revision=0;this.sent=null;this.clock=null;}
 receive(message){
  if(!this.active()||this.session.closed)return;
  this.weather?.receive(message);
  if(message.kind==='client-area'||message.kind==='module-time'&&('timeOfDay' in message.changes||'transition' in message.changes)){
   this.clock={areaId:this.session.world.areaId,generation:this.session.areaGeneration,at:this.now(),transition:this.session.world.time.transition??0};this.revision++;
  }else if(message.kind==='module-info')this.revision++;
  this.flush();
 }
 flush(){
  const scope=this.ready(),s=this.session;
  if(!this.active()||s.closed||!scope||scope.connection!==this.connection||scope.areaId!==s.world.areaId||scope.generation!==s.areaGeneration)return false;
  const area=s.world.registry.get(scope.areaId)?.state,clock=this.clock;
  if(!area||!clock||clock.areaId!==scope.areaId||clock.generation!==scope.generation)return false;
  this.sky?.flush(area.fields.e0);
  this.weather?.flush();
  const key=[scope.connection,scope.areaId,scope.generation,scope.transferId,this.revision].join(':');if(this.sent===key)return false;
  const fields=Object.fromEntries(offsets.filter(k=>Number.isFinite(area.fields[k])||typeof area.fields[k]==='boolean').map(k=>[k,area.fields[k]]));
  this.send({kind:'area-environment',...scope,revision:this.revision,state:{fields,time:{timeOfDay:s.world.time.timeOfDay,transition:clock.transition},minutesPerHour:s.world.module?.minutesPerHour,elapsed:Math.fround((clock.transition+Math.max(0,this.now()-clock.at))/1000)}});
  this.sent=key;return true;
 }
 async close(){await Promise.allSettled([this.sky?.close(),this.weather?.close()]);}
}
