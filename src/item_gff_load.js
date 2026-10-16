import {getGffFieldTypes} from './gff.js';
import {readNativeGff,nativeAssignedString} from './native_gff_fields.js';
import {objectTemplateResRef} from './create_object.js';

// Serialized records always use metadata. Old host-side semantic fixtures
// already supply decoded values; they have no serialized field-width claim.
export function readItemGffField(data,kind,name,fallback){
 const type={resref:11,byte:0,bool:0,dword:4,word:2,list:15,struct:14,string:10}[kind];
 if(type===undefined)throw new Error(`Native item ${kind} field reader is unavailable`);
 let result;
 if(getGffFieldTypes(data))result=readNativeGff(data,name,type,fallback);
 else if(!Object.hasOwn(data,name))result={status:0,value:fallback};
 else{
  const value=data[name],valid=kind==='list'?Array.isArray(value):kind==='struct'?value!==null&&typeof value==='object'&&!Array.isArray(value):kind==='resref'||kind==='string'?typeof value==='string':Number.isInteger(value);
  if(!valid)throw new Error(`Native semantic item ${name} value is unavailable`);result={status:1,value};
 }
 if(kind==='resref')result.value=objectTemplateResRef(result.value);
 else if(kind==='string')result.value=nativeAssignedString(result.value);
 else if(kind==='bool')result.value=Number((result.value&255)!==0);
 else if(kind==='byte')result.value&=255;else if(kind==='word')result.value&=65535;else if(kind==='dword')result.value>>>=0;
 return result;
}

// Complete CNWSItem::LoadFromGff14046a9d0..14046ac02. Template presence is
// determined by typed-read STATUS, even for an empty resref. EquippedRes has
// priority. Its flag overrides use raw BYTEs; InventoryRes uses BYTE-as-BOOL.
// Embedded data alone runs the saved-state owner and post-load visual update.
export async function loadItemFromGff(item,data,loading,lastFlag,p){
 let reference=await p.read(data,'resref','EquippedRes',''),equipped=(reference.status|0)!==0;
 if(!equipped)reference=await p.read(data,'resref','InventoryRes','');
 if(equipped||(reference.status|0)!==0){
  const result=await p.loadTemplate(item,reference.value);
  for(const[name,offset]of[['Dropable',0x448],['Pickpocketable',0x44c]]){
   const entry=await p.read(data,equipped?'byte':'bool',name,0);
   if((entry.status|0)!==0)await p.field(item,offset,entry.value);
  }
  return result;
 }
 if((await p.loadData(item,data,loading,lastFlag))===0)return 0;
 await p.savedState(item,data);await p.addTag(item);await p.visual(item);return 1;
}
