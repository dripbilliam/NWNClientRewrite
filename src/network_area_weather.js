// Original server1404cebd0 -> client area dispatcher14076d910/minor4.
// The message affects the current area; it carries no fabricated object ID.
import {GAME_OBJECT_TYPE} from './game_object_array.js';
export function readAreaWeather(reader){return{kind:'area-weather',weather:{type:reader.readByte(),enabled:reader.readBool()}};}
export function applyAreaWeather(world,message){
 const area=world.registry.get(world.areaId),value=message.weather;
 if(!area?.state||area.objectType!==GAME_OBJECT_TYPE.area||area.replicationRemoved)return false;
 if(!value||!Number.isInteger(value.type)||value.type<0||value.type>255||![0,1].includes(value.enabled))throw Error('Invalid native area weather state');
 area.state.weather={type:value.type,enabled:value.enabled};return true;
}
