import {cloneGff} from './gff.js';
import {readNativeGff,nativeAssignedString} from './native_gff_fields.js';
import {localizedMessageValue} from './native_message_text.js';
import {loadStoreData} from './store_template.js';
import {addStoreItem} from './store_item_acquisition.js';
import {nativeObjectTag} from './object_tag.js';
import {objectTemplateResRef} from './create_object.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {setItemIdentified} from './item_identification.js';
import {setItemPossessor} from './item_possession.js';
import {repositoryAdd} from './item_repository.js';
import {addModuleTag} from './module_tag_lookup.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const fields={0x378:'BlackMarket',0x37c:'BM_MarkDown',0x380:'MarkDown',0x384:'MarkUp',0x38c:'StoreGold',0x390:'IdentifyPrice',0x394:'MaxBuyPrice'};
export function readStoreGff(record,kind,name,fallback){
 const type={string:10,localized:12,bool:0,int:5,dword:4,resref:11,list:15}[kind];
 if(type===undefined)throw new Error(`Native store ${kind} GFF reader is unavailable`);
 const entry=readNativeGff(record,name,type,fallback);
 if(kind==='bool')entry.value=Number((entry.value&255)!==0);else if(kind==='int')entry.value|=0;else if(kind==='dword')entry.value>>>=0;else if(kind==='resref')entry.value=objectTemplateResRef(entry.value);else if(kind==='string')entry.value=nativeAssignedString(entry.value);return entry;
}
export function releaseStoreFields(object){
 for(const offset of[0x3a8,0x398])if(object.nativeStoreBuyArrays)object.nativeStoreBuyArrays[offset]=null;
 object.nativeStoreName360=null;
 for(const offset of[0x318,0x308])if(object.nativeStoreStrings)object.nativeStoreStrings[offset]='';
}
export class StoreRuntime{
 constructor(session){this.session=session;}
 acquisitionProviders(store){
  const s=this.session;return{
   baseInfo:o=>s.items.baseInfo(o),price:(...args)=>s.items.price(...args),repository:(o,panel)=>{const repo=o.nativeStoreRepositories?.[panel];if(!repo)throw new Error('Native store panel repository is unavailable');return repo;},
   head:r=>r.head,tail:r=>r.tail,item:(_r,node)=>{const item=s.registry.get(node.id);return item?.objectType===6?item:null;},previous:(_r,node)=>node.previous,removeNode:(r,node)=>r.removeNode(node),
   add:(...args)=>repositoryAdd(...args,s.itemRepositoryProviders()),warning:message=>runtimeDiagnostics.record('items.store-warning',message,s.diagnosticContext(store.id)),
  };
 }
 async addItem(store,ref,panel,x,y){
  try{return await addStoreItem(store,ref,panel,x,y,this.acquisitionProviders(store));}
  finally{store.inventory=store.nativeStoreRepositories.flatMap(repo=>[...repo.ids()]);}
 }
 async load(object,data,loading=0,newTag=''){
  const s=this.session;object.authored=cloneGff(data);object.nativeStoreInventoryImported=true;
  const context={...s.diagnosticContext(object.id),operation:'native-store-data-load'},read=readStoreGff;
  try{return await loadStoreData(object,loading,newTag,{
   read:(...args)=>read(data,...args),asTag:nativeObjectTag,setTag:(o,value)=>{o.tag=nativeObjectTag(value);},
   localized:(o,offset,value)=>{if(offset!==0x360)throw new Error('Native store localized field is unavailable');o.nativeStoreName360=localizedMessageValue(value);o.name=value.entries[0]?.text??'';o.authored.LocName=cloneGff(value);},
   field:(o,offset,value)=>{if(!fields[offset])throw new Error('Native store field is unavailable');(o.nativeStoreFields??={})[offset]=value|0;o.authored[fields[offset]]=value|0;},
   string:(o,offset,value)=>{
    value=nativeAssignedString(value);if(offset===0x30){o.templateResRef=value;return;}
    const key={0x308:'openStore',0x318:'closedStore'}[offset];if(!key)throw new Error('Native store string is unavailable');(o.nativeStoreStrings??={})[offset]=value;
    Object.defineProperty(o.scripts??={},key,{enumerable:true,configurable:true,get:()=>o.nativeStoreStrings[offset],set:value=>{o.nativeStoreStrings[offset]=nativeAssignedString(value);}});
   },
   list:name=>read(data,'list',name,[]),rowList:(row,name)=>read(row.value,'list',name,[]),count:list=>list.value.length,element:(list,index)=>({status:1,value:list.value[index]}),readRow:(row,...args)=>read(row.value,...args),
   arrayCount:(o,offset)=>o.nativeStoreBuyArrays[offset].values.length,appendType:(o,offset,value)=>{const array=o.nativeStoreBuyArrays[offset];if(array.values.length===array.capacity)array.capacity=array.capacity?array.capacity*2:16;array.values.push(value|0);},
   existing:id=>s.registry.get(id),newItem:requestedId=>s.register('item',`runtime:store-item:${object.id}:${requestedId===OBJECT_INVALID?`new:${s.registry.nextObjectId[0]}`:`saved:${requestedId}`}`,{areaId:OBJECT_INVALID,authored:{},tag:'',deferTagLookup:true,equipmentSlot:null},{requestedId}),
   loadItem:async(item,row,flag,last)=>{try{return await s.items.loadFromGff(item,row.value,{loading:flag,insideContainer:last});}catch(error){s.report(error,{...s.diagnosticContext(item.id),operation:'native-store-item-load',storeId:object.id});return 0;}},destroyItem:item=>s.lifecycle.destroy(item),
   itemField:(item,offset,value)=>{if(offset!==0x444)throw new Error('Native store item field is unavailable');item.nativeInfinite444=value|0;},identified:setItemIdentified,baseInfo:item=>s.items.baseInfo(item),price:(...args)=>s.items.price(...args),
   warning:message=>runtimeDiagnostics.record('items.store-warning',message,context),acquire:(...args)=>this.addItem(...args),setPossessor:(...args)=>setItemPossessor(...args,s.itemOwnershipProviders()),
   addTag:o=>addModuleTag(s.tags,o.tag,o.id),loadUUID:o=>s.loadNativeUUID(o,data),
  });}catch(error){s.report(error,context);throw error;}
  finally{object.inventory=object.nativeStoreRepositories.flatMap(repo=>[...repo.ids()]);}
 }
}
