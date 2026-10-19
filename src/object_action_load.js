import {readNativeGff} from './native_gff_fields.js';
import {encodeGffText} from './gff_text.js';
import {addObjectAction} from './object_actions.js';

// Whole CNWSObject::LoadActionQueue1404963f0..1404969a2. Temporary scalar/
// string values become owned copies through the existing AddAction owner;
// VM situations transfer their actual owner. No queue clear or direct count
// restoration: group sentinels and type-zero termination belong to AddAction.
export async function loadObjectActions(state,data,p={}){
 const read=p.read??readNativeGff,list=read(data,'ActionList',15,null);if(list.status===0)return;
 let parameters,current,situation,loadedSituation;
 const get=(r,n,t,d)=>read(r,n,t,d).value;
 for(const row of list.value){
  const id=get(row,'ActionId',4,0)>>>0,group=get(row,'GroupActionId',2,0)&65535,count=get(row,'NumParams',2,0)&65535;
  if(count>12)throw new Error('Native saved action count exceeds temporary parameter storage');
  const values=[];
  if(count!==0){
   const nested=read(row,'Paramaters',15,null);if(nested.status!==0)parameters=nested.value;
   else if(parameters===undefined)throw new Error('Native saved action parameter list is uninitialized');
   for(let i=0;i<count;i++){
    if(i<parameters.length)current=parameters[i];
    else if(current===undefined)throw new Error('Native saved action parameter struct is uninitialized');
    const type=get(current,'Type',4,0)>>>0;let value=0;
    if(type===1)value=get(current,'Value',5,0)|0;
    else if(type===2){const bits=new DataView(new ArrayBuffer(4));bits.setFloat32(0,get(current,'Value',8,0),true);value=bits.getInt32(0,true);}
    else if(type===3)value=get(current,'Value',4,0)|0;
    else if(type===4)value=encodeGffText(get(current,'Value',10,''));
    else if(type===5){
     const nested=read(current,'Value',14,null);if(nested.status!==0)situation=nested.value;
     else if(situation===undefined)throw new Error('Native saved action script-situation struct is uninitialized');
     value=await p.scriptSituation(situation,loadedSituation);loadedSituation=value;
    }
    else if(type===6)value=get(current,'Value',0,0)&255;
    values.push({type,value});
   }
  }
  (p.add??addObjectAction)(state,id,group,values);
 }
}
