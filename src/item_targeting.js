import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item target ${n} is unavailable`);return v|0;};

// Shared selected definition in ActivateSpellTarget140703ea0 and its creature
// veto140703d00. The high WORD255 means parent; other values narrow to BYTE
// only when selecting the subradial child. It is not generic spell targeting.
export function itemSpellTargetDefinition(item,packed,p){
 packed=integer(packed,'packed selection');
 let id=p.propertySpell(item,packed&65535)>>>0,spell=p.spell(id);
 if(spell&&((packed>>>16)&65535)!==255&&(spell.children.length&255)>0){id=p.subRadialSpell(spell,(packed>>>16)&255)>>>0;spell=p.spell(id);}
 return spell;
}

// Decoded targeting policy of ActivateActionTarget1407039f0 and nested
// ActivateSpellTarget140703ea0. The wheel supplies a blank custom icon;
// allocation/custom-icon/lifetime ownership is separate from this policy.
// Preview presentation is explicit. Missing metadata leaves an empty targeter.
export function prepareItemTarget(itemId,packed,p,{autoSelf=1,inventoryMode=0,containerMode=0}={}){
 itemId=integer(itemId,'item ID')>>>0;packed=integer(packed,'packed selection');
 const item=p.item(itemId);if(!item)return{mode:'unavailable'};
 const prop=p.property(item,packed&65535);if(!prop)return{mode:'unavailable'};
 const state={mode:'target',itemId,packed,point:[0,0,0],targetId:OBJECT_INVALID,targetTypes:[],flags:0,creatureVeto:false,definition:null};
 const type=integer(prop.type,'property type')&65535;
 if(type===15){
  state.flags=31;state.creatureVeto=true;const spell=itemSpellTargetDefinition(item,packed,p);state.definition=spell;
  if(!spell)return state;
  const mask=spell.targetType&65535,base=p.baseInfo(item);let self=false;
  if(base){
   const behavior=integer(base.qbBehaviour,'QBBehaviour')&255;
   if(behavior===2||mask===1)self=(autoSelf&255)!==0;
   else if(mask===9)self=(autoSelf&255)!==0&&inventoryMode!==1&&containerMode!==1;
  }
  if(self){state.mode='self';state.targetId=p.controlledId()>>>0;return state;}
  for(const [bit,objectType]of [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]])if(mask&bit)state.targetTypes.push([objectType,29]);
  p.preview(spell);return state;
 }
 if(type===55){state.flags=43;state.targetTypes=[[10,41],[9,41]];}
 else if(type===70){state.flags=35;state.targetTypes=[[2,33],[5,33],[10,33],[9,33]];}
 else if(type===80){state.flags=57;state.targetTypes=[[2,55],[5,55],[10,55],[9,55]];}
 else p.warning('ActivateActionTarget: unsupported active property type');
 return state;
}

export function itemCreatureTargetVeto(itemId,packed,targetId,p){
 const item=p.item(integer(itemId,'item ID')>>>0);if(!item)return 1;
 const spell=itemSpellTargetDefinition(item,packed,p);if(!spell)return 1;
 const target=p.creature(integer(targetId,'target ID')>>>0);if(!target)return 0;
 const mask=spell.targetType&65535;
 if(!(mask&1)&&target.id===p.controlledId())return 1;
 if(!(mask&2)&&target.id!==p.controlledId())return 1;
 return 0;
}

// Target confirmation140703860 and client wrapper140805740. An inventory
// item target uses the possessing creature's point when it exists. Other
// targets retain the current targeter's point. Final scalar encoding belongs
// to the transport adapter, not this owner.
export async function confirmItemTarget(state,p){
 const actor=p.player();if(!actor)return;
 const target=p.item(state.targetId>>>0);
 if(target){const possessor=p.creature(target.possessorId>>>0);state.point=[...p.position(possessor??target)];}
 await p.use(actor,state.itemId>>>0,state.packed|0,state.targetId>>>0,[...state.point]);
 await p.clearPreview(0);await p.clearRange(0);await p.dispose(state);
}

// Client UseItem140805740. The downstream message writer owns scalar
// encoding; retain BYTE property and arithmetic high-WORD argument here.
export async function sendItemUse(itemId,packed,targetId,point,p){
 const transport=p.transport();if(!transport)return;
 packed=integer(packed,'packed selection');
 await p.send(transport,integer(itemId,'item ID')>>>0,packed&255,packed>>16,integer(targetId,'target ID')>>>0,[...point]);
}
