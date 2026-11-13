// Original world-context GUI26 contract. No menu/rule/render projection.
import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
export const GUI_CONTEXT_SOURCES=Object.freeze(Object.fromEntries([
 ['ground',16,null],['trigger',17,7],['creature',18,5],
 ['item',19,6],['placeable',20,9],['door',21,10]
].map(([name,panelId,objectType])=>[name,Object.freeze({panelId,objectType,selection:panelId-15})])));
export const guiContextSource=value=>typeof value==='string'&&Object.hasOwn(GUI_CONTEXT_SOURCES,value)?GUI_CONTEXT_SOURCES[value]:null;
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff;
export const guiContextPosition=value=>Array.isArray(value)&&value.length===3&&value.every(n=>typeof n==='number'&&Number.isFinite(n)&&Number.isFinite(Math.fround(n)));
export function guiContextOpenRequest({sourceKind,targetId,position,includePosition}){
 const source=guiContextSource(sourceKind);
 if(!source||!uint(targetId)||typeof includePosition!=='boolean'||!guiContextPosition(position)||sourceKind==='ground'&&targetId!==OBJECT_INVALID||sourceKind!=='ground'&&(targetId===OBJECT_INVALID||position.some(n=>n!==0)))throw Error('Invalid native world-context GUI event');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(26);w.writeWord(source.selection);w.writeObjectIdClient(targetId);
 if(includePosition)for(const n of position)w.writeFloat(n,1,32);
 w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
