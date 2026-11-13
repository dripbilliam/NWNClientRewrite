// Original UpdateWind4ce930 -> client dispatcher76d910/minor13. This only
// decodes protocol state; the native Godot scene owns all wind simulation.
import {GAME_OBJECT_TYPE} from './game_object_array.js';
const names=['e8','ec','f0','f4','f8','fc'];
export function readAreaWind(reader){return {kind:'area-wind',fields:Object.fromEntries(names.map(name=>[name,reader.readFloat()]))};}
export function applyAreaWind(world,message){
 const area=world.registry.get(world.areaId);if(!area?.state||area.objectType!==GAME_OBJECT_TYPE.area||area.replicationRemoved)return false;
 if(!message.fields||names.some(name=>typeof message.fields[name]!=='number'||!Number.isFinite(message.fields[name])))throw Error('Invalid native area wind fields');
 area.state.fields??={};Object.assign(area.state.fields,message.fields,{e4:3});return true;
}
