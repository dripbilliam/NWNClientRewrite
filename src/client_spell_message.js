import {OBJECT_INVALID} from './game_object_array.js';
import {serverObjectIdForClient} from './client_projectile_message.js';

// CC8 branch of client dispatcher770c80, verified jump-table target7760c1.
// Scalar reads, spell/name/TLK lookup, token parsing and output are lower owners.
// These bytes are the original widget's name/message color control strings.
export const spellMessageColors={self:String.fromCharCode(60,99,153,255,255,62),other:String.fromCharCode(60,99,204,153,204,62),message:String.fromCharCode(60,99,204,119,255,62)};
export function readSpellCombatMessage(p){
 const sourceId=p.objectId()>>>0,spellId=p.dword(32)>>>0,identified=p.bool()|0,casting=p.bool()|0,hasItem=p.bool()|0;
 let itemName='',baseItem;
 if(p.overflow()!==0)return null;
 if(hasItem===1){if(identified===1)itemName=p.bool()!==0?p.localizedString(0,0):p.string(32);else baseItem=p.byte(8,1)&255;}
 if(p.overflow()!==0)return null;
 return{sourceId,spellId,identified,casting,hasItem,itemName,baseItem};
}
// One decision tree for synchronous local and asynchronous network text owners.
// Yielding services preserves native call/token order across resource fetches.
function* spellMessageSteps({sourceId,spellId,identified,casting,hasItem,itemName,baseItem}){
 const spell=yield['spell',spellId|0];let message='';
 function* sourceName(){
  let name=yield['sourceName',sourceId];
  if(name!==null){const player=yield['player'];if(player){const same=((yield['player']).id>>>0)===sourceId;name=(same?spellMessageColors.self:spellMessageColors.other)+name+'</c>';}}
  else name=yield['tlk',0x209d];
  yield['token',0,name];
 };
 if(spell){
  if((spell.altMessage|0)!==0){yield*sourceName();message=spellMessageColors.message+(yield['parse',spell.altMessage>>>0])+'</c>';}
  else{
   const verb=yield['tlk',casting===1&&hasItem===0?0x1fbf:hasItem===0?0x5dd:0xf720];let name;
   if(identified!==0)name=hasItem===0?(yield['tlk',spell.name>>>0]):itemName;
   else if(hasItem===0)name=yield['tlk',0x5de];
   else{yield['token',0,yield['baseItemName',baseItem]];name=yield['parse',0xf721];}
   yield*sourceName();yield['token',1,verb];yield['token',2,name];message=spellMessageColors.message+(yield['parse',0x28f2])+'</c>';
  }
 }
 yield['display',message,128,0,0,''];
}
export function receiveSpellCombatMessage(p){
 const fields=readSpellCombatMessage(p);if(!fields)return false;
 const steps=spellMessageSteps(fields);let step=steps.next();
 while(!step.done){const [service,...args]=step.value;step=steps.next(p[service](...args));}return true;
}
export async function presentSpellCombatMessage(fields,p){
 const steps=spellMessageSteps(fields);let step=steps.next();
 while(!step.done){const [service,...args]=step.value;step=steps.next(await p[service](...args));}
}

// Local scalar projection of SendServerToPlayerCCMessage4cf090 case8. It has
// already-decoded message data, not native packet bytes. BOOL keeps the low bit;
// the writer's item-name branch tests the original INT for exactly1 first.
export function localSpellMessageFields(data,p){
 const fields=[],add=(type,value)=>fields.push({type,value}),object=i=>data.objects?.[i]??OBJECT_INVALID,int=i=>(data.integers?.[i]??0)|0;
 add('object',serverObjectIdForClient(object(0)));add('dword',int(0)>>>0);add('bool',int(1)&1);add('bool',int(2)&1);
 if((object(1)>>>0)===OBJECT_INVALID)add('bool',0);
 else{
  add('bool',1);
  if(int(1)!==1)add('byte',int(3)&255);
  else{
   const item=p.item(object(1)>>>0);
   if(!item)p.warning('Native CC8 item lookup failed',{itemId:object(1)>>>0});
   else{const name=p.itemName(item);if(name.override.length===0){add('bool',1);add('localized',name.localized);}else{add('bool',0);add('string',name.override);}}
  }
 }
 return fields;
}
export function localSpellMessageReader(fields){
 let index=0,failed=0;
 const take=type=>{const value=fields[index++];if(!value||value.type!==type){failed=1;return type==='string'||type==='localized'?'':0;}return value.value;};
 return{objectId:()=>take('object'),dword:()=>take('dword'),bool:()=>take('bool'),byte:()=>take('byte'),string:()=>take('string'),localizedString:()=>take('localized'),overflow:()=>failed};
}
