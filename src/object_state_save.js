import {gffField as field,gffRecord as record} from './gff_writer.js';
import {decodeGffText} from './gff_text.js';
import {readNativeGff} from './native_gff_fields.js';

const integer=(v,n)=>{if(typeof v==='boolean')v=Number(v);if(!Number.isInteger(v))throw new Error(`Native object save ${n} is unavailable`);return v|0;};
const uint=(v,n)=>integer(v,n)>>>0;
const float=(v,n)=>{if(typeof v!=='number')throw new Error(`Native object save ${n} FLOAT is unavailable`);return Math.fround(v);};
const text=(v,n)=>{if(typeof v!=='string')throw new Error(`Native object save ${n} string is unavailable`);return v;};
const array=(v,n,size)=>{if(!Array.isArray(v)||size!==undefined&&v.length!==size)throw new Error(`Native object save ${n} storage is unavailable`);return v;};
const put=(root,name,type,value)=>{root.fields[name]=field(type,value);};
const list=(root,name)=>{const entries=[];put(root,name,15,entries);return entries;};
const element=(entries,type)=>{const node=record({},type);entries.push(node);return node;};

// Complete CGameEffect::SaveGameEffect140424d50..14042510d. Property IDs,
// link pointers and padding are NOT additional serialized effect fields.
export function saveGameEffect(effect,root=record({})){
 if(typeof effect.id!=='string'||!/^[0-9a-f]{1,16}$/i.test(effect.id))throw new Error('Native effect save uint64 ID is unavailable');
 put(root,'Id',6,BigInt(`0x${effect.id}`));put(root,'Type',2,integer(effect.type,'effect type')&65535);
 put(root,'SubType',2,(integer(effect.subtype,'effect subtype')|integer(effect.durationType,'effect duration'))&65535);
 put(root,'Duration',8,float(effect.duration,'effect duration'));put(root,'SkipOnLoad',0,integer(effect.skipOnLoad,'skip-on-load')&255);
 for(const [name,key]of [['ExpireDay','expiryDay'],['ExpireTime','expiryTime'],['CreatorId','creatorId'],['CasterLevel','casterLevel'],['SpellId','spellId']])put(root,name,4,uint(effect[key],key));
 put(root,'IsExposed',5,integer(effect.exposed,'exposure'));put(root,'IsIconShown',5,integer(effect.showIcon,'icon state'));
 const ints=array(effect.integers,'effect integers');put(root,'NumIntegers',5,ints.length|0);put(root,'CustomTag',10,text(effect.customTag,'custom tag'));put(root,'IgnoreImmunity',5,integer(effect.bypassImmunity,'immunity flag'));
 if(ints.length){const entries=list(root,'IntList');for(const value of ints)put(element(entries,3),'Value',5,integer(value,'effect integer'));}
 for(const [name,values,type,kind]of [['FloatList',array(effect.floats,'effect floats',4),8,4],['StringList',array(effect.strings,'effect strings',6),10,5],['ObjectList',array(effect.objectIds,'effect objects',4),4,6]]){
  const entries=list(root,name);for(const value of values)put(element(entries,kind),'Value',type,type===8?float(value,'effect float'):type===10?text(value,'effect string'):uint(value,'effect object ID'));
 }
 const vectors=list(root,'VectorList');for(const vector of array(effect.vectors,'effect vectors',2)){
  array(vector,'effect vector',3);const node=element(vectors,7);for(let i=0;i<3;i++)put(node,`Value${'XYZ'[i]}`,8,float(vector[i],'effect vector coordinate'));
 }
 return root;
}

// Complete CScriptLocation::SaveLocation1402e99b0..1402e9a7b. Stored native
// XYZ and area ID are copied without resolution or orientation normalization.
export function saveLocalLocation(location,root=record({})){
 put(root,'Area',4,uint(location.areaId,'location area'));const orientation=array(location.nativeOrientation,'location orientation',3),position=array(location.position,'location position',3);
 for(let i=0;i<3;i++)put(root,`Orientation${'XYZ'[i]}`,8,float(orientation[i],'location orientation'));
 for(let i=0;i<3;i++)put(root,`Position${'XYZ'[i]}`,8,float(position[i],'location position'));return root;
}

// Complete SaveVarTable1405080b0..140508496. Physical hash-list order is
// supplied by the canonical table owner, not reconstructed from sorted names.
export async function saveScriptVariables(rows,p,root=record({})){
 const entries=list(root,'VarTable');
 for(const [name,entry]of rows){
  text(name,'variable name');
  const add=type=>{const node=element(entries,0);put(node,'Name',10,name);put(node,'Type',4,type);return node;};
  const fv=float(entry.float,'local float');if(fv!==0)put(add(2),'Value',8,fv);
  const iv=integer(entry.int,'local int');if(iv!==0)put(add(1),'Value',5,iv);
  const id=uint(entry.object,'local object ID');if(id!==0x7f000000)put(add(4),'Value',4,id);
  const string=text(entry.string,'local string');if(string.length!==0)put(add(3),'Value',10,string);
  const location=entry.location;
  if(location!==null){
   const pos=array(location.position,'local position',3),rot=array(location.nativeOrientation,'local orientation',3);
   if(uint(location.areaId,'local area')!==0x7f000000||[...pos,...rot].some(n=>float(n,'local location coordinate')!==0)){
    const value=record({},1);put(add(5),'Value',14,value);saveLocalLocation(location,value);
   }
  }
  for(const [kind,type,struct]of [['cswy',6,2],['json',7,3]])if(!await p.engineEmpty(kind,entry[kind])){
   const value=record({},struct);put(add(type),'Value',14,value);await p.saveEngine(kind,entry[kind],value);
  }
 }
 return root;
}

// Complete CNWSObject::SaveActionQueue140499910..140499bf7. The original
// label is literally "Paramaters". Unknown types emit Type without Value.
export async function saveObjectActions(object,p,root=record({})){
 const entries=list(root,'ActionList'),client=await p.client(object);
 if(client&&integer(p.clientFieldD4(client),'client fieldD4')!==0)return root;
 const queue=p.actions(object);if(!queue?.list)throw new Error('Native action save list is unavailable');const visited=new Set();
 for(let link=queue.list.head;link;link=link.next){
  if(visited.has(link))throw new Error('Native action save linked-list cycle');visited.add(link);
  const action=link.action;if(!action)throw new Error('Native action save node is unavailable');
  const node=element(entries,0),count=integer(action.parameterCount,'action parameter count')&65535;
  put(node,'ActionId',4,uint(action.actionId,'action ID'));put(node,'GroupActionId',2,integer(action.groupId,'action group')&65535);put(node,'NumParams',2,count);
  if(count!==0){
   if(count>12)throw new Error('Native action save parameter count exceeds its inline storage');
   const params=list(node,'Paramaters');
   for(let i=0;i<count;i++){
    const type=uint(action.parameterTypes[i],'action parameter type'),value=action.parameterData[i],entry=element(params,1);put(entry,'Type',4,type);
    if(type===1)put(entry,'Value',5,integer(value,'action INT'));
    else if(type===2){const bits=new DataView(new ArrayBuffer(4));bits.setInt32(0,integer(value,'action FLOAT bits'),true);put(entry,'Value',8,bits.getFloat32(0,true));}
    else if(type===3)put(entry,'Value',4,uint(value,'action object ID'));
    else if(type===4){if(!(value instanceof Uint8Array))throw new Error('Native action save string bytes are unavailable');put(entry,'Value',10,decodeGffText(value));}
    else if(type===5){const situation=record({},2);put(entry,'Value',14,situation);await p.scriptSituation(value,situation);}
    else if(type===6)put(entry,'Value',0,integer(value,'action BYTE')&255);
   }
  }
 }
 return root;
}

// Complete CNWSTransition::SaveToGff1404fe7e0..1404fe845.
export function saveObjectTransition(transition,root=record({})){
 const node=record({},1);put(root,'Transition',14,node);put(node,'TargetTag',10,text(transition.targetTag,'transition tag'));put(node,'TargetObjectId',4,uint(transition.targetObjectId,'transition target'));return root;
}
// Complete LoadFromGff1404fe610..1404fe6d7: absent struct retains state;
// failed typed reads retain the current tag and target ID (sixth/fifth args).
export function loadObjectTransition(transition,data,read=readNativeGff){
 const nested=read(data,'Transition',14,null);if(nested.status===0)return transition;
 transition.targetTag=read(nested.value,'TargetTag',10,transition.targetTag).value;
 transition.targetObjectId=read(nested.value,'TargetObjectId',4,transition.targetObjectId).value;return transition;
}

// Complete CNWSObject::SaveObjectState14049a350..14049a470 coordinator.
export async function saveObjectState(object,p,root=record({})){
 const effects=()=>array(p.effects(object),'object effects');
 if(effects().length>0){
  const entries=list(root,'EffectList');for(let i=0;i<effects().length;i++){
   const effect=effects()[i],duration=(integer(effect.subtype,'effect subtype')|integer(effect.durationType,'effect duration'))&7;
   if(duration===3||((integer(object.objectType,'object type')&255)===6&&duration!==1))continue;
   await p.effect(effect,element(entries,2));
  }
 }
 await p.variables(object,root);await p.actionsSave(object,root);await p.transition(object,root);return root;
}
