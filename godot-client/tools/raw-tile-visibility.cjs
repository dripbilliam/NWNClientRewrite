// Fresh decoded PlayerInfo mask0x200 deliveries only. Godot owns native tile
// setters, reveal/fade/scene links. Never replay sticky snapshot.automap state.
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const flag=value=>typeof value==='boolean'||value===0||value===1;
const {rawEntityLifetime:lifetime}=require('./raw-entity-lifetime.cjs');
class RawTileVisibility{
 constructor(project=(world,actor)=>actor){if(typeof project!=='function')throw new TypeError('Visibility identity projection must be callable');this.project=project;this.serial=0;this.unavailable=0;}
 frames(world,message,generation,connection){
  if(message.kind!=='object-updates')return[];
  const output=[];
  for(const row of message.records??[]){
   if(row.action!=='player-state'||!Object.hasOwn(row.state??{},'automap'))continue;
   if(!uint(connection)||!uint(generation)||!uint(world.areaId)||row.id!==world.localObjectId){this.unavailable++;continue;}
   const actor=world.registry.get(row.id),change=row.state.automap;
   if(!actor||actor.replicationRemoved||actor.areaId!==world.areaId||!Array.isArray(change?.mode)||change.mode.length!==2||change.mode.some(v=>!flag(v))){this.unavailable++;continue;}
   let detached;
   if(change.mode[1]){
    if(!(change.bytes instanceof Uint8Array||Array.isArray(change.bytes))||change.bytes.length>255||Array.from(change.bytes).some(v=>!Number.isInteger(v)||v<0||v>255)){this.unavailable++;continue;}
    detached={mode:change.mode.map(Boolean),bytes:Array.from(change.bytes)};
   }else{
    if(!Array.isArray(change.points)||change.points.length>131072||change.points.some(p=>!p||!Number.isInteger(p.x)||p.x<0||p.x>255||!Number.isInteger(p.y)||p.y<0||p.y>255||!change.mode[0]&&!flag(p.state))){this.unavailable++;continue;}
    detached={mode:change.mode.map(Boolean),points:change.points.map(p=>change.mode[0]?{x:p.x,y:p.y}:{x:p.x,y:p.y,state:Boolean(p.state)})};
   }
   const projected=this.project(world,actor);
   if(!projected||projected.id!==actor.id){this.unavailable++;continue;}
   output.push({kind:'raw-tile-visibility',connection,generation,areaId:world.areaId,actorId:row.id,lifetime:lifetime(projected),serial:++this.serial,change:detached});
  }
  return output;
 }
}
module.exports={RawTileVisibility};
