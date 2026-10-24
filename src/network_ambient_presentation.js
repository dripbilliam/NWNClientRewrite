import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {nativeOneShotSoundCue} from './native_audio.js';
import {NativeAmbientOwner} from './native_ambient.js';
import {StreamingAudio} from './streaming_audio.js';
import {scriptStringCase} from './script_string.js';

export function resolveAmbientTrack(table,id,music){
 const row=Number.isInteger(id)&&id>=0?table?.orderedRows?.[id]:null;
 const cell=name=>{const value=row?.[name];return !value||value==='****'?'':scriptStringCase(value,true);};
 return{resource:cell('Resource'),stingers:music?['Stinger1','Stinger2','Stinger3'].map(cell):[]};
}
// The active area owns these streams, independently of the canonical object
// table. Commands arriving during table IO keep their native receive order.
export class NetworkAmbientPresentation{
 constructor({output,getResource,report=()=>{},now=()=>performance.now(),createStream=(output,options)=>new StreamingAudio(output,options)}){Object.assign(this,{output,getResource,report,now,createStream});this.generation=0;this.pending=[];}
 async attach(area,resolver){
  this.detach();const generation=this.generation;this.areaId=area.id;this.loading=true;
  try{
   const [music,ambient]=await Promise.all(['ambientmusic','ambientsound'].map(async name=>parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)))));
   if(generation!==this.generation)return;
   if(!this.reportedAdapter){this.reportedAdapter=true;this.report('network.ambient-mixer-clock-unimplemented','Native area audio mixer settings and synchronized pause timing are not connected; category gain defaults and a monotonic presentation clock are used',{});}
   const failure=(kind)=>(error,context)=>{if(generation!==this.generation)return;this.report('network.ambient-resource-failed',error.message,{areaId:area.id,stream:kind,...context});if(kind==='ambient')this.owner.ambientFailed=1;else{this.owner.retry=10000;this.owner.lastTime=this.now();}};
   const streams={music:this.createStream(this.output,{getResource:this.getResource,loop:false,onFailure:failure('music')}),ambient:this.createStream(this.output,{getResource:this.getResource,loop:true,onFailure:failure('ambient')})};
   this.owner=new NativeAmbientOwner({state:area.ambient,streams,resolve:(isMusic,id)=>{try{return resolveAmbientTrack(isMusic?music:ambient,id,isMusic);}catch(error){this.report('network.ambient-resource-case-unhandled',error.message,{areaId:area.id,table:isMusic?'ambientmusic':'ambientsound',id});return{resource:'',stingers:[]};}},stinger:resRef=>{void this.output.play({...nativeOneShotSoundCue({resRef,priority:1,channel:'music-stinger'}),objectId:0x7f000000,current:()=>generation===this.generation});}});
   this.owner.captureClock=()=>{this.owner.lastTime=this.now();};this.owner.dayNight(area.time.timeOfDay);this.owner.start();this.loading=false;
   for(const command of this.pending.splice(0))this.owner.command(command);
  }catch(error){if(generation===this.generation){this.loading=false;this.pending=[];this.report('network.ambient-load-failed',error.message,{areaId:area.id});}}
 }
 receive(message){if(message.kind!=='ambient-command')return;if(this.owner)this.owner.command(message);else if(this.loading){if(this.pending.length<128)this.pending.push(message);else this.report('network.ambient-command-overflow','Too many area audio commands awaiting tables',{areaId:this.areaId});}else this.report('network.ambient-owner-unavailable','Area audio command has no active presentation owner',{areaId:this.areaId,operation:message.operation});}
 update(timeOfDay){if(!this.owner)return;this.owner.dayNight(timeOfDay);this.owner.frame(this.now());}
 detach(){this.generation++;this.owner?.dispose();this.owner=null;this.pending=[];this.loading=false;this.areaId=null;}
 snapshot(){return{areaId:this.areaId,loading:this.loading,pending:this.pending.length,owner:this.owner?.snapshot()??null,streams:this.owner?Object.fromEntries(Object.entries(this.owner.streams).map(([k,s])=>[k,s.snapshot()])):null};}
 dispose(){this.detach();}
}
