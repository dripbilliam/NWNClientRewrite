import {readNativeGff} from './native_gff_fields.js';
import {nativeItemTag} from './item_stack_compare.js';

// CScriptLocation::LoadLocation1402e9830..1402e99a1. Missing fields use0,
// including Area. There is no area resolution, coordinate conversion or facing
// normalization. The six copied coordinates are native XYZ.
export function loadLocalLocation(data,read=readNativeGff){
 const areaId=read(data,'Area',4,0).value,position=[],nativeOrientation=[];
 for(const name of ['OrientationX','OrientationY','OrientationZ'])nativeOrientation.push(read(data,name,8,0).value);
 for(const name of ['PositionX','PositionY','PositionZ'])position.push(read(data,name,8,0).value);
 return{areaId,position,nativeOrientation};
}

// Complete LoadVarTable140507640..140507edc (the switch table starts atedc).
// Lower typed reads and structured-engine loads/copies are explicit providers.
// Loading overlays individual typed cells; no initial clear or name-level reset.
export function loadScriptVariableRows(table,rows,p={}){
 const read=p.read??readNativeGff;
 const slots=new Map();
 const structure=(record,kind)=>{
  const result=read(record,'Value',14,null);
  if(result.status!==0)slots.set(kind,result.value);
  // GetStruct1401a04e0 leaves its output untouched on failure. Each switch
  // branch has a separate CResStruct local, retained across list iterations.
  else if(!slots.has(kind))p.uninitializedStruct?.(kind);
  return slots.get(kind)??null;
 };
 for(const record of rows){
  const name=read(record,'Name',10,'').value,type=read(record,'Type',4,0).value;
  switch(type){
   case 1:table.setInt(name,read(record,'Value',5,0).value,1);break;
   case 2:table.setFloat(name,read(record,'Value',8,0).value);break;
   case 3:table.setString(name,read(record,'Value',10,'').value);break;
   case 4:table.setObject(name,read(record,'Value',4,0).value);break;
   case 5:table.setLocation(name,loadLocalLocation(structure(record,'location'),read));break;
   case 6:{
    const value=p.loadCswy(structure(record,'cswy'));
    p.setCswy(table,name,value);
    // The original has no jump/break after the solver branch: type6 also
    // loads the JSON cell from this same record's Value structure.
   }
   // fall through
   case 7:{
    const data=structure(record,'json');let value=p.createJson();
    const json=read(data,'JSON',10,'');
    if(json.status!==0&&nativeItemTag(json.value).length!==0)value=p.parseJson(json.value);
    p.setJson(table,name,value);break;
   }
  }
 }
}
export function loadScriptVariables(table,data,p={}){
 const list=(p.read??readNativeGff)(data,'VarTable',15,null);
 if(list.status!==0)loadScriptVariableRows(table,list.value,p);
}
