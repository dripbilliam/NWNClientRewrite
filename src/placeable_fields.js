import {nativeAssignedString} from './native_gff_fields.js';
import {localizedMessageValue} from './native_message_text.js';
import {decodeGffText} from './gff_text.js';
import {objectTemplateResRef} from './create_object.js';
// Live cells shared by the full placeable data loader, synthetic body bags,
// existing gameplay getters and the native message-field view.
const aliases={0x3d0:'nativeTrapType3d0',0x3c8:'nativeTrapRecoverable3c8',0x3d4:'nativeTrapActive3d4',0x3d8:'nativeTrapFaction3d8',0x368:'nativeGroundPile368',0x59c:'nativeBodyBag59c',0x5a4:'nativeStaticLoadOverride5a4',0x5a0:'nativeStatic5a0',0x4f8:'nativeHasInventory4f8',0x504:'nativeField504',0x510:'nativeBodyBagSource510',0x514:'nativeField514'};
const authored={0x3a4:'AutoRemoveKey',0x350:'Faction',0x3a8:'OpenLockDC',0x3bc:'TrapDisarmable',0x3c0:'TrapDetectable',0x3b8:'DisarmDC',0x3b0:'TrapDetectDC',0x3b4:'TrapFlag',0x3c4:'TrapOneShot',0x3d0:'TrapType',0x3c8:'TrapRecoverable',0x3d4:'TrapActive',0x3d8:'TrapFaction',0x3ac:'TrapCreator',0x510:'LootCreature',0x514:'IsBodyBag',0x264:'Useable',0x5a0:'Static',0x32c:'Appearance',0xe4:'HP',0xe0:'CurrentHP',0x370:'Hardness',0x4e0:'Fort',0x4e1:'Will',0x4e2:'Ref',0x500:'Lockable',0x378:'Locked',0x4f8:'HasInventory',0x3a0:'KeyRequired',0x3a9:'CloseLockDC',0x59c:'BodyBag',0x504:'DieWhenEmpty',0x368:'GroundPile',0x594:'LightState',0xcc:'AnimationDay',0xd0:'AnimationTime'};
export function placeableField(object,offset,value,width=4){
 const fields=object.nativeMessageFields??={};
 if(value===undefined){
  const result=offset===0xfc?Number(object.plot):aliases[offset]?object[aliases[offset]]:fields[offset];
  if(!Number.isInteger(result))throw new Error(`Native placeable field ${offset.toString(16)} is unavailable`);return result;
 }
 if(!Number.isInteger(value)||![1,2,4].includes(width))throw new Error('Native placeable field storage is unavailable');
 value=width===1?value&255:width===2?value&65535:value|0;fields[offset]=value;
 if(aliases[offset])object[aliases[offset]]=value;
 const root=object.authored??={};if(authored[offset])root[authored[offset]]=value;
 if(offset===0xfc){object.plot=value!==0;root.Plot=value;}
 else if(offset===0x264){object.usable=value!==0;object.nativeUseable264=value;}
 else if(offset===0x350)object.factionId=value>>>0;
 else if(offset===0x378)object.locked=value;
 else if(offset===0x3b4)object.trapped=value;
 else if(offset===0x370)object.hardness=value&255;
 else if(offset===0xe0)object.currentHP=value;
 // LoadBodyBag writes Fort+Will together as a WORD; normal UTP loading
 // writes them as separate BYTEs. Both views must see the same high byte.
 else if(offset===0x4e0&&width===2){root.Fort=value&255;root.Will=value>>>8;fields[0x4e1]=value>>>8;}
 return value;
}
const scripts={0x3e0:'closed',0x3f0:'damaged',0x400:'death',0x410:'disarm',0x420:'heartbeat',0x430:'disturbed',0x440:'lock',0x450:'attacked',0x460:'open',0x470:'spellAt',0x480:'trapTriggered',0x490:'unlock',0x4a0:'used',0x4b0:'userDefined',0x4c0:'dialogue',0x4d0:'click'};
export function placeableString(object,offset,value){
 if(typeof value!=='string')throw new Error('Native placeable string storage is unavailable');
 value=nativeAssignedString(value);(object.nativeBodyBagStrings??={})[offset]=value;
 if(scripts[offset]){
  const callbacks=object.scripts??={};Object.defineProperty(callbacks,scripts[offset],{enumerable:true,configurable:true,get:()=>object.nativeBodyBagStrings[offset],set:v=>{object.nativeBodyBagStrings[offset]=nativeAssignedString(v);}});
 }
 const name={0x318:'DisplayName',0x340:'DescriptionOverride',0x380:'KeyName',0x390:'KeyRequiredFeedbackMessage',0x580:'Portal'}[offset];if(name)(object.authored??={})[name]=value;
}
export function placeableResref(object,offset,value){
 const fields=object.nativeBodyBagResrefs??={};
 if(value===undefined){if(typeof fields[offset]!=='string')throw new Error('Native placeable resource-reference storage is unavailable');return fields[offset];}
 fields[offset]=objectTemplateResRef(value);const name={0x568:'TemplateResRef',0x354:'Conversation'}[offset];if(name)(object.authored??={})[name]=fields[offset];return fields[offset];
}
export function placeableLocalized(object,offset,value){
 const native=localizedMessageValue(value);(object.nativePlaceableLocalized??={})[offset]=native;
 const projected={strRef:native.strRef,entries:native.entries.map(entry=>({languageId:entry.key,text:decodeGffText(entry.bytes)}))};
 (object.nativeBodyBagLocalized??={})[offset]=projected;
 if(offset===0x308){(object.authored??={}).LocName=projected;object.name=projected.entries[0]?.text??'';}
 else if(offset===0x330)(object.authored??={}).Description=projected;
}
// Common virtual setters:4233a0 tail-copies CResRef to40 without changing
// WORD52. SetPortraitId49b930 looks up active portraits/BaseResRef, prefixes
// po_, copies through CResRef, then stores the original WORD ID.
export function objectPortraitRef(object,value){object.nativePortraitResRef=objectTemplateResRef(value);}
export async function objectPortraitId(object,value,p){
 value&=65535;
 await p.setRef(object,value>=65534?'':objectTemplateResRef(`po_${(await p.baseResRef(value,'BaseResRef')).value}`));
 object.nativePortraitId=value;
}

// Placeable destructor4afe4c..4aff23, after repository/area/AI/tag removal:
// portal, trap-known IDs, reverse script array, key feedback/name, override,
// localized description, display name, localized name. Trivial CResRefs remain.
export function releasePlaceableFields(object){
 const clear=offset=>{if(object.nativeBodyBagStrings&&Object.hasOwn(object.nativeBodyBagStrings,offset))object.nativeBodyBagStrings[offset]='';};
 clear(0x580);object.nativeTrapKnownIds?.setSize(0);
 for(let offset=0x4d0;offset>=0x3e0;offset-=0x10)clear(offset);
 for(const offset of[0x390,0x380,0x340])clear(offset);
 if(object.nativePlaceableLocalized)object.nativePlaceableLocalized[0x330]=null;
 if(object.nativeBodyBagLocalized)object.nativeBodyBagLocalized[0x330]=null;
 clear(0x318);
 if(object.nativePlaceableLocalized)object.nativePlaceableLocalized[0x308]=null;
 if(object.nativeBodyBagLocalized)object.nativeBodyBagLocalized[0x308]=null;
}
