import {nativeStringEntry} from '../../src/spell_metadata.js';import {intEntry} from '../../src/combat_stats.js';
// Metadata/state delivery only. Original-model precipitation presentation is a
// separate owner; no particles, local weather rolls or server AI run here.
export class WeatherDelivery{
 constructor({session,connection,active,ready,rules,send,models,diagnose=()=>{}}){Object.assign(this,{session,connection,active,ready,rules,send,models,diagnose});this.revision=0;this.source=null;this.sent=null;this.closed=false;this.jobs=new Set();}
 receive(message){
  if(this.closed||this.session.closed||!this.active()||!['client-area','area-weather'].includes(message.kind))return;
  const s=this.session,area=s.world.registry.get(s.world.areaId)?.state;
  if(!area?.weather)return;
  this.source={world:s.world,areaId:s.world.areaId,generation:s.areaGeneration,weather:{...area.weather},revision:++this.revision};this.flush();
 }
 valid(source,scope){const s=this.session,now=this.ready();return !this.closed&&!s.closed&&this.active()&&this.source===source&&source.world===s.world&&source.areaId===s.world.areaId&&source.generation===s.areaGeneration&&now&&['connection','areaId','generation','transferId'].every(k=>now[k]===scope[k]);}
 flush(){
  const scope=this.ready(),s=this.session,source=this.source;
  if(!source||!scope||scope.connection!==this.connection||scope.areaId!==source.areaId||scope.generation!==source.generation||source.world!==s.world||!this.valid(source,scope))return;
  const key=[scope.connection,scope.areaId,scope.generation,scope.transferId,source.revision].join(':');if(this.sent===key)return;this.sent=key;
  const job=this.prepare(source,{...scope}).catch(error=>{if(this.valid(source,scope))this.diagnose('godot.weather-metadata-failed',error.message);}).finally(()=>this.jobs.delete(job));this.jobs.add(job);
 }
 async prepare(source,scope){
  const table=await this.rules('weathertypes');if(!this.valid(source,scope))return;
  const string=(id,name)=>{const entry=nativeStringEntry(table,id,name);return entry.found?entry.value:null;};
  const rows={};for(let i=0;i<Math.min(256,table.orderedRows?.length??0);i++){const fade=intEntry(table,i,'FadeTime');rows[i]={model:string(i,'Model'),animation:string(i,'Animation'),lightning:string(i,'ModelLightning'),fadeTime:fade.found?fade.value:6000};}
  const message={kind:'weather-state',...scope,revision:source.revision,weather:{type:source.weather.type,enabled:source.weather.enabled!==0},rows,presentationPending:true};this.send(message);
  await this.models?.receive(message,source.world);
 }
 async close(){this.closed=true;this.source=null;await this.models?.close();await Promise.allSettled([...this.jobs]);}
}
