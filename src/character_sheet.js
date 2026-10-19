import {OBJECT_INVALID} from './game_object_array.js';
import {createCombatInformation,disposeCombatInformation} from './combat_information.js';

const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native character sheet ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native character-sheet provider ${n} is unavailable`);return p[n](...args);};

// CNWCreatureStatsUpdate14050a680. Scalar values initialized by the original
// constructor are retained by offset. Unwritten padding is not invented state;
// owned arrays/pointers are represented separately from these scalar bytes.
export function createCharacterStatsUpdate(skillCount){
  skillCount=integer(skillCount,'skill count')&255;
  const scalars=new Uint8Array(0x70),initialized=new Uint8Array(0x70),view=new DataView(scalars.buffer);
  const set=(offset,size,value)=>{if(size===4)view.setUint32(offset,value>>>0,true);else if(size===2)view.setUint16(offset,value&65535,true);else scalars[offset]=value&255;initialized.fill(1,offset,offset+size);};
  for(const[offset,size,value]of [[0x5c,4,-21],[0x56,4,0xffecffec],[0x3e,4,0xebebebeb],[0x42,4,0xececebeb],[0x38,4,0xebebebeb],[0x3c,2,0xebeb],[0x49,2,0xecec],[0x68,2,0xffec],[0x46,2,0xecec],[0x48,1,0xec],[0x4b,2,0xecec],[0x4d,1,0xec],[0x60,4,0],[0x4e,4,0xecececec],[0x52,4,0xecececec],[0x64,4,0x818181ff]])set(offset,size,value);
  return{scalars,initialized,lists:[[],[]],effectIcons:[],effectIconCapacity:0,combat:createCombatInformation(),skills:skillCount?new Uint8Array(skillCount).fill(0xec):null};
}

// ClearEffectIcons14050a8c0 removes from the tail, retaining array capacity.
export function clearCharacterEffectIcons(update,p){
  if(!update)throw new Error('Native character-sheet effect icons dereference a null update');
  for(let index=update.effectIcons.length-1;index>=0;index--){const icon=update.effectIcons[index];if(icon!==null)call(p,'releaseIcon',icon);update.effectIcons.splice(index,1);}
}
// Destructor14050a790 releases each independently owned allocation. JS lists
// own records rather than fabricated native heap pointers.
export function disposeCharacterStatsUpdate(update,p){
  update.lists[0].length=update.lists[1].length=0;update.skills=null;
  if(update.combat){disposeCombatInformation(update.combat);update.combat=null;}
  clearCharacterEffectIcons(update,p);update.effectIconCapacity=0;update.disposed=true;
}
// Embedded GUI construction1404b79da..1404b7a32: target INVALID, signed page-1,
// separately owned update, force DWORD1. No creature subscription is invented.
export function createCharacterSheetGUI(skillCount){return{targetId:OBJECT_INVALID,page:-1,update:createCharacterStatsUpdate(skillCount),force:1};}

// SetCreatureDisplayed1404be500. Same target preserves update identity. A null
// old update remains null even when the target changes (native allocation path).
export function setCharacterSheetTarget(gui,targetId,p){
  targetId=integer(targetId,'target ID')>>>0;
  if((integer(gui.targetId,'previous target ID')>>>0)!==targetId&&gui.update){call(p,'dispose',gui.update);gui.update=call(p,'create');}
  gui.targetId=targetId;
}

// PermittedToDisplayCharacterSheet1404bd020. A DM requires a live target too;
// ordinary permission is controlled self or a direct associate of that self.
export function permittedCharacterSheet(client,targetId,p){
  if(!call(p,'serverAvailable'))return 0;
  const target=call(p,'creature',integer(targetId,'target ID')>>>0);if(!target)return 0;
  const info=call(p,'playerInfo',client);if(info&&integer(info.dm,'DM flag')!==0)return 1;
  const controlled=call(p,'creature',integer(call(p,'controlledId',client),'controlled ID')>>>0);if(!controlled)return 0;
  return (integer(target.id,'target object ID')>>>0)===(integer(controlled.id,'controlled object ID')>>>0)||(integer(target.masterId,'master ID')>>>0)===(controlled.id>>>0)?1:0;
}

// Complete decoded HandlePlayerToServerCharacterSheetMessage140444e00.
// Codec/profiling and actual transport are explicit external boundaries.
export function receiveCharacterSheetInput(client,subtype,p){
  subtype=integer(subtype,'subtype')&255;
  let page=(integer(call(p,'readChar'),'page')<<24)>>24,targetId=integer(call(p,'readObjectId'),'target ID')>>>0;
  if(integer(call(p,'overflow'),'overflow')!==0||integer(call(p,'underflow'),'underflow')!==0)return 0;
  if(subtype===1){
    if(call(p,'permitted',client,targetId)===0){page=-1;call(p,'notPermitted',client,targetId);targetId=OBJECT_INVALID;}
    const gui=call(p,'gui',client),previous=call(p,'creature',integer(gui.targetId,'previous target ID')>>>0);
    if(previous)previous.nativeField540=(integer(previous.nativeField540,'previous consumers')-1)|0;
    const next=call(p,'creature',targetId);if(next)next.nativeField540=(integer(next.nativeField540,'next consumers')+1)|0;
    call(p,'setTarget',gui,targetId);gui.page=page;
    if(page===-1)call(p,'clearIcons',gui.update);
  }
  return 1;
}
