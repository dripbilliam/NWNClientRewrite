import {parseGff,cloneGff} from './gff.js';
import {readNativeGff,nativeAssignedString} from './native_gff_fields.js';
import {localizedMessageValue} from './native_message_text.js';
import {loadWorldObjectTemplate} from './world_object_template.js';
import {loadWaypointData} from './waypoint_template.js';
import {loadPlaceableData} from './placeable_template.js';
import {StoreRuntime} from './store_runtime.js';
import {placeableField,placeableString,placeableResref,placeableLocalized,objectPortraitRef,objectPortraitId} from './placeable_fields.js';
import {nativeObjectTag} from './object_tag.js';
import {placeableMessageLight} from './area_message_pack.js';
import {intEntry} from './combat_stats.js';
import {spellStringEntry} from './spell_metadata.js';
import {acquirePlaceableItem} from './item_acquisition.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {objectTemplateResRef} from './create_object.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {addModuleTag} from './module_tag_lookup.js';
const f=Math.fround,render=v=>[f(v[0]),f(v[2]),f(-v[1])];

// Runtime providers for the independently compared template/data owners.
// Add new kinds only through their complete native data-loader adapters.
export class WorldTemplateRuntime{
 constructor(session){this.session=session;this.stores=new StoreRuntime(session);}
 async load(kind,object,reference,newTag=''){
  const s=this.session,context={...s.diagnosticContext(object.id),kind,resource:reference,operation:'native-world-template-load'};
  if(object.objectType!==({waypoint:12,placeable:9,store:14}[kind])||s.registry.get(object.id)!==object)
   s.combat.unsupported(object,`Native ${kind} world-template data adapter is unavailable`);
  try{return await loadWorldObjectTemplate(kind,object,reference,newTag,{
   resource:async(type,signature,name)=>{
    try{return{loaded:1,data:parseGff(await s.resolver.getResource(name,type),signature).root};}
    catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;s.report(error,{...context,resource:name,resourceType:type});return{loaded:0,data:null};}
   },
   root:r=>r.data,release:(r,flag)=>{if(flag!==1)throw new Error('Native template resource release flag is unavailable');r.data=null;},
   warning:message=>runtimeDiagnostics.record('object.template-warning',message,context),
   setTemplate:(o,name)=>{o.templateResRef=name;},
   loadData:(kind,o,_resource,data,flagOrTag,tag)=>kind==='waypoint'?this.loadWaypoint(o,data,flagOrTag):kind==='placeable'?this.loadPlaceable(o,data,flagOrTag,tag):this.stores.load(o,data,flagOrTag,tag),
   loadVariables:(o,_resource,data)=>s.loadNativeVariables(o,data),
  });}catch(error){s.report(error,context);throw error;}
 }
 async loadPlaceable(object,data,loading=0,newTag=''){
  const s=this.session;object.authored=cloneGff(data);
  if(!object.nativeRepository)throw new Error('Native placeable constructor repository is unavailable');
  object.nativeInventoryImported=true;
  const read=(record,kind,name,fallback)=>{
   const type={string:10,float:8,bool:0,byte:0,word:2,short:3,dword:4,int:5,localized:12,resref:11,list:15}[kind];
   if(type===undefined)throw new Error(`Native placeable ${kind} field reader is unavailable`);
   const result=readNativeGff(record,name,type,fallback);
   if(kind==='bool')result.value=Number((result.value&255)!==0);else if(kind==='byte')result.value&=255;
   else if(kind==='word')result.value&=65535;else if(kind==='short')result.value=result.value<<16>>16;
   else if(kind==='resref')result.value=objectTemplateResRef(result.value);return result;
  };
  const lightColor=async(row,column)=>{const table=await s.items.table('placeables'),entry=table?intEntry(table,row,column):{found:false,value:0};return{status:Number(entry.found),value:entry.value};};
  try{return await loadPlaceableData(object,loading,newTag,{
   read:(...args)=>read(data,...args),field:placeableField,string:placeableString,resref:placeableResref,localized:placeableLocalized,
   asTag:nativeObjectTag,setTag:(o,tag)=>{o.tag=nativeObjectTag(tag);},setTemplate:(o,value)=>{o.templateResRef=nativeAssignedString(value);},
   portraitId:(o,value)=>objectPortraitId(o,value,{setRef:objectPortraitRef,baseResRef:async(row,column)=>{const table=await s.items.table('portraits');return{value:table?spellStringEntry(table,row,column):''};}}),portrait:objectPortraitRef,
   light:o=>placeableMessageLight(o,{field:(o,offset)=>placeableField(o,offset),lightColor}),lightColor,
   getScript:(o,selector)=>{if(selector!==10)throw new Error('Native placeable script selector is unavailable');return o.scripts.trapTriggered;},
   trapScript:async(row,column)=>{const table=await s.items.table('traps');return table?spellStringEntry(table,row,column):'';},
   animation:(o,value)=>{o.nativeAnimationD8=value|0;},
   list:name=>read(data,'list',name,[]),count:list=>list.value.length,element:(list,index)=>list.value[index],readItem:read,
   newItem:requestedId=>s.register('item',`runtime:placeable-item:${object.id}:${requestedId===OBJECT_INVALID?`new:${s.registry.nextObjectId[0]}`:`saved:${requestedId}`}`,{tag:'',areaId:OBJECT_INVALID,position:[0,0,0],authored:{},deferTagLookup:true,equipmentSlot:null},{requestedId}),
   loadItem:async(item,row,flag,last)=>{try{return await s.items.loadFromGff(item,row,{loading:flag,insideContainer:last});}catch(error){s.report(error,{...s.diagnosticContext(item.id),operation:'native-placeable-item-load',containerId:object.id});return 0;}},
   destroyItem:item=>s.lifecycle.destroy(item),acquire:(...args)=>acquirePlaceableItem(...args,s.itemAcquisitionProviders()),
   visual:(o,owner)=>s.objectVisuals.loadOwner(o,data,owner),loadUUID:o=>s.loadNativeUUID(o,data),addTag:o=>addModuleTag(s.tags,o.tag,o.id),
  });}finally{object.inventory=[...object.nativeRepository.ids()];}
 }
 async loadWaypoint(object,data,newTag=''){
  const s=this.session;object.authored=cloneGff(data);
  return loadWaypointData(object,newTag,{
   read:(kind,name,fallback)=>{
    const type={string:10,float:8,bool:0,localized:12,resref:11}[kind];
    if(type===undefined)throw new Error(`Native waypoint GFF reader ${kind} is unavailable`);
    const result=readNativeGff(data,name,type,fallback);
    if(kind==='bool')result.value=Number((result.value&255)!==0);
    else if(kind==='resref')result.value=objectTemplateResRef(result.value);
    return result;
   },
   setTag:(o,tag)=>{o.tag=nativeAssignedString(tag);},
   localized:(o,offset,value)=>{
    if(offset===0x310)o.nativeMapNote310=localizedMessageValue(value);
    else if(offset===0x320){o.nativeName320=localizedMessageValue(value);o.name=nativeAssignedString(value.entries[0]?.text??'');} // compatibility UI label
    else throw new Error('Native waypoint localized field is unavailable');
   },
   position:(o,point,flag)=>s.setPosition(o,render(point),flag),
   orientation:(o,vector)=>{o.orientation=render(vector);o.nativeOrientation=[...vector];},
   setTemplate:(o,name)=>{o.templateResRef=name;},
   addTag:o=>addModuleTag(s.tags,o.tag,o.id),
   loadUUID:o=>s.loadNativeUUID(o,data),
  });
 }
}
