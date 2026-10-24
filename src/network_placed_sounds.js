import {NativePlacedSound,nativeSoundTileIndex} from './native_placed_sound.js';
import {BufferAudioSource} from './buffer_audio_source.js';
import {GAME_OBJECT_TYPE} from './game_object_array.js';
export class NetworkPlacedSounds{
 constructor({world,output,report=()=>{},now=()=>performance.now(),createSource=(output,options)=>new BufferAudioSource(output,options)}){Object.assign(this,{world,output,report,now,createSource});this.owners=new Map();}
 attach(area){this.detach();this.area=area;for(const record of this.world().registry.objects.values())if(record.areaId===area.id&&record.objectType===GAME_OBJECT_TYPE.sound)this.add(record);}
 add(record){
  if(this.owners.has(record.id)||!this.area||record.areaId!==this.area.id)return;
  if(!this.reportedMixer){this.reportedMixer=true;this.report('network.placed-sound-mixer-unhandled','Native sound-object priority voice limits, range-resume sample phase and synchronized pause timing are not connected',{});}
  let source;try{
   source=this.createSource(this.output,{objectId:record.id,onFailure:(error,data)=>this.report('network.placed-sound-resource-failed',error.message,data)});
   const area={width:this.area.width,height:this.area.height,tileHeightAt:point=>{const index=nativeSoundTileIndex(point,this.area.width,this.area.height);return index<0?null:this.area.tiles[index]?.fields['18'];}};
   const owner=new NativePlacedSound({sound:record.state,source,area,now:this.now()});owner.timeGate(this.world().time);this.owners.set(record.id,owner);
   if(!owner.refs.length){owner.active=0;this.report('network.placed-sound-empty-list','Native active sound object has no sound references',{objectId:record.id});}
  }catch(error){source?.dispose();this.report('network.placed-sound-create-failed',error.message,{objectId:record.id});}
 }
 receive(message){
  if(message.kind!=='sound-object')return;const record=this.world().registry.get(message.objectId);
  if(message.operation===6){if(record?.objectType===GAME_OBJECT_TYPE.sound)this.add(record);return;}
  const owner=this.owners.get(message.objectId);if(!owner)return;
  if(message.operation===2)owner.play(this.now());else if(message.operation===3)owner.stop();else if(message.operation===4)owner.setVolume(message.volume);else if(message.operation===5&&record)owner.move(record.state.position);else if(message.operation===7){owner.dispose();this.owners.delete(message.objectId);}
 }
 update(){const world=this.world(),now=this.now();if(world.areaId!==this.area?.id)return;for(const [id,owner]of this.owners){if(!world.registry.get(id)){owner.dispose();this.owners.delete(id);continue;}try{owner.timeGate(world.time);owner.frame(now,world.time);}catch(error){owner.stop();this.report('network.placed-sound-frame-failed',error.message,{objectId:id});}}}
 detach(){for(const owner of this.owners.values())owner.dispose();this.owners.clear();this.area=null;}
 snapshot(){return{areaId:this.area?.id??null,objects:[...this.owners.values()].map(owner=>owner.snapshot())};}
 dispose(){this.detach();}
}
